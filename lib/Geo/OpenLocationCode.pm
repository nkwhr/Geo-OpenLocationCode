package Geo::OpenLocationCode;
use 5.008001;
use strict;
use warnings;
use base qw/Exporter/;
use Carp;
use List::Util qw/min max/;
use POSIX qw/floor fmod/;

our $VERSION = '0.01';

our @EXPORT = qw/get_alphabet encode decode is_valid is_short is_full recover_nearest shorten/;

use constant {
    SEPARATOR => '+',
    SEPARATOR_POSITION => 8,
    PADDING_CHARACTER => '0',
    CODE_ALPHABET => '23456789CFGHJMPQRVWX',
    ENCODING_BASE => 20,
    LATITUDE_MAX => 90,
    LONGITUDE_MAX => 180,
    PAIR_CODE_LENGTH => 10,
    PAIR_RESOLUTIONS => [20.0, 1.0, 0.05, 0.0025, 0.000125],
    GRID_COLUMNS => 4,
    GRID_ROWS => 5,
    GRID_SIZE_DEGREES => 0.000125,
    MIN_TRIMMABLE_CODE_LEN => 6,
};

sub get_alphabet {
    return CODE_ALPHABET;
}

sub is_valid {
    my $code = shift;

    if (! $code) {
        return 0;
    }

    my $pos = index($code, SEPARATOR);

    if ($pos == -1 || $pos != rindex($code, SEPARATOR)) {
        return 0;
    }

    if (length($code) == 1) {
        return 0;
    }

    if ($pos > SEPARATOR_POSITION || $pos % 2 == 1) {
        return 0;
    }

    if (index($code, PADDING_CHARACTER) > -1) {
        if (index($code, PADDING_CHARACTER) == 0) {
            return 0;
        }

        my @pad_match = ($code =~ /(${ \(PADDING_CHARACTER) }+)/g);

        if (scalar(@pad_match) > 1 ||
            length($pad_match[0]) % 2 == 1 ||
            length($pad_match[0]) > SEPARATOR_POSITION - 2) {
            return 0;
        }

        if (substr($code, length($code) - 1, 1) ne SEPARATOR) {
            return 0;
        }
    }

    if (length($code) - $pos - 1 == 1) {
        return 0;
    }

    $code =~ s/\Q${ \(SEPARATOR) }//;
    $code =~ s/\Q${ \(PADDING_CHARACTER) }//g;
    $code = uc $code;

    for my $char (split //, $code) {
        if ($char ne SEPARATOR && index(CODE_ALPHABET, $char) == -1) {
            return 0;
        }
    }
    return 1;
}

sub is_short {
    my $code = shift;

    if (! is_valid($code)) {
        return 0;
    }

    my $pos = index($code, SEPARATOR);

    if ($pos >= 0 && $pos < SEPARATOR_POSITION) {
        return 1;
    }

    return 0;
}

sub is_full {
    my $code = shift;

    if (! is_valid($code) || is_short($code)) {
        return 0;
    }

    my $first_lat_value = index(CODE_ALPHABET, substr(uc $code, 0, 1)) * ENCODING_BASE;

    if ($first_lat_value >= LATITUDE_MAX * 2) {
        return 0;
    }

    if (length $code > 1) {
        my $first_lng_value = index(CODE_ALPHABET, substr(uc $code, 1, 1)) * ENCODING_BASE;
        if ($first_lng_value >= LONGITUDE_MAX * 2) {
            return 0;
        }
    }

    return 1;
}

sub encode {
    my ($latitude, $longitude, $code_length) = @_;

    if (! defined $code_length) {
        $code_length = PAIR_CODE_LENGTH;
    }

    if ($code_length < 2 || ($code_length < SEPARATOR_POSITION && $code_length % 2 == 1)) {
        croak 'Invalid Open Location Code length';
    }

    $latitude = _clip_latitude($latitude);
    $longitude = _normalize_longitude($longitude);

    if ($latitude == 90) {
        $latitude = $latitude - _compute_latitude_precision($code_length);
    }

    my $code = _encode_pairs($latitude, $longitude, min($code_length, PAIR_CODE_LENGTH));

    if ($code_length > PAIR_CODE_LENGTH) {
        $code .= _encode_grid($latitude, $longitude, $code_length - PAIR_CODE_LENGTH);
    }

    return $code;
}

sub decode {
    my $code = shift;

    if (! is_full($code)) {
        croak "Passed Open Location Code is not a valid full code: $code";
    }

    $code =~ s/\Q${ \(SEPARATOR) }//;
    $code =~ s/\Q${ \(PADDING_CHARACTER) }//g;
    $code = uc $code;

    my $code_area = _decode_pairs(substr($code, 0, PAIR_CODE_LENGTH));

    if (length($code) <= PAIR_CODE_LENGTH) {
        return $code_area;
    }

    my $grid_area = _decode_grid(substr($code, PAIR_CODE_LENGTH, length($code) - PAIR_CODE_LENGTH));

    return Geo::OpenLocationCode::CodeArea->new(
        $code_area->latitude_lo  + $grid_area->latitude_lo,
        $code_area->longitude_lo + $grid_area->longitude_lo,
        $code_area->latitude_lo  + $grid_area->latitude_hi,
        $code_area->longitude_lo + $grid_area->longitude_hi,
        $code_area->code_length  + $grid_area->code_length,
    );
}

sub recover_nearest {
    my ($short_code, $reference_latitude, $reference_longitude) = @_;

    if (! is_short($short_code)) {
        if (is_full($short_code)) {
            return $short_code;
        } else {
            croak "Passed short code is not valid: $short_code";
        }
    }

    $reference_latitude = _clip_latitude($reference_latitude);
    $reference_longitude = _normalize_longitude($reference_longitude);

    $short_code = uc $short_code;

    my $padding_length = SEPARATOR_POSITION - index($short_code, SEPARATOR);

    my $resolution = 20 ** (2 - ($padding_length / 2));
    my $area_to_edge = $resolution / 2.0;

    my $rounded_latitude = floor($reference_latitude / $resolution) * $resolution;
    my $rounded_longitude = floor($reference_longitude / $resolution) * $resolution;

    my $code_area = decode(
        substr(encode($rounded_latitude, $rounded_longitude), 0, $padding_length) . $short_code
    );

    my $degrees_difference = $code_area->latitude_center - $reference_latitude;

    if ($degrees_difference > $area_to_edge) {
        $code_area->latitude_center -= $resolution;
    } elsif ($degrees_difference < -$area_to_edge) {
        $code_area->latitude_center += $resolution;
    }

    $degrees_difference = $code_area->longitude_center - $reference_longitude;

    if ($degrees_difference > $area_to_edge) {
        $code_area->longitude_center -= $resolution;
    } elsif ($degrees_difference < -$area_to_edge) {
        $code_area->longitude_center += $resolution;
    }

    return encode(
        $code_area->latitude_center,
        $code_area->longitude_center,
        $code_area->code_length
    );
}

sub shorten {
    my ($code, $latitude, $longitude) = @_;

    if (! is_full($code)) {
        croak "Passed code is not valid and full: $code";
    }

    if (index($code, PADDING_CHARACTER) != -1) {
        croak "Cannot shorten padded codes: $code";
    }

    $code = uc $code;
    my $code_area = decode($code);
    if ($code_area->code_length < MIN_TRIMMABLE_CODE_LEN) {
        croak 'Code length must be at least ' . MIN_TRIMMABLE_CODE_LEN;
    }

    $latitude = _clip_latitude($latitude);
    $longitude = _normalize_longitude($longitude);

    my $range = max(
        abs($code_area->latitude_center - $latitude),
        abs($code_area->longitude_center - $longitude)
    );

    for (my $i = scalar(@{PAIR_RESOLUTIONS()}) - 2 ; $i >= 1; $i--) {
        if ($range < (PAIR_RESOLUTIONS->[$i] * 0.3)) {
            my $pos = ($i + 1) * 2;
            return substr($code, $pos, length($code) - $pos);
        }
    }
    return $code;
}

sub _clip_latitude {
    my $latitude = shift;
    return min(90, max(-90, $latitude));
}

sub _compute_latitude_precision {
    my $code_length = shift;
    if ($code_length <= 10) {
        return 20 ** (floor($code_length / -2.0 + 2));
    }
    return (20 ** -3) / (GRID_ROWS ** ($code_length - 10));
}

sub _normalize_longitude {
    my $longitude = shift;
    while ($longitude < -180) {
        $longitude += 360;
    }
    while ($longitude >= 180) {
        $longitude -= 360;
    }
    return $longitude;
}

sub _encode_pairs {
    my ($latitude, $longitude, $code_length) = @_;

    my $adjusted_latitude = $latitude + LATITUDE_MAX;
    my $adjusted_longitude = $longitude + LONGITUDE_MAX;

    my $code = '';
    my $digit_count = 0;

    while ($digit_count < $code_length) {
        my $place_value = PAIR_RESOLUTIONS->[floor($digit_count / 2)];
        my $digit_value = floor($adjusted_latitude / $place_value);

        $adjusted_latitude -= $digit_value * $place_value;
        $code .= substr(CODE_ALPHABET, $digit_value, 1);
        $digit_count++;

        $digit_value = floor($adjusted_longitude / $place_value);
        $adjusted_longitude -= $digit_value * $place_value;
        $code .= substr(CODE_ALPHABET, $digit_value, 1);
        $digit_count++;

        if ($digit_count == SEPARATOR_POSITION && $digit_count < $code_length) {
            $code .= SEPARATOR;
        }
    }
    if (length $code < SEPARATOR_POSITION) {
        $code .= PADDING_CHARACTER x (SEPARATOR_POSITION - length($code));
    }

    if (length($code) == SEPARATOR_POSITION) {
        $code .= SEPARATOR;
    }

    return $code;
}

sub _encode_grid {
    my ($latitude, $longitude, $code_length) = @_;

    my $code = '';
    my $lat_place_value = GRID_SIZE_DEGREES;
    my $lng_place_value = GRID_SIZE_DEGREES;
    my $adjusted_latitude = fmod($latitude + LATITUDE_MAX, $lat_place_value);
    my $adjusted_longitude = fmod($longitude + LONGITUDE_MAX, $lng_place_value);

    for (0..$code_length-1) {
        my $row = floor($adjusted_latitude / ($lat_place_value / GRID_ROWS));
        my $col = floor($adjusted_longitude / ($lng_place_value / GRID_COLUMNS));
        $lat_place_value = $lat_place_value / GRID_ROWS;
        $lng_place_value = $lng_place_value / GRID_COLUMNS;
        $adjusted_latitude -= $row * $lat_place_value;
        $adjusted_longitude -= $col * $lng_place_value;
        $code .= substr(CODE_ALPHABET, $row * GRID_COLUMNS + $col, 1);
    }

    return $code;
}

sub _decode_pairs {
    my $code = shift;

    my $latitude = _decode_pairs_sequence($code, 0);
    my $longitude = _decode_pairs_sequence($code, 1);

    return Geo::OpenLocationCode::CodeArea->new(
        $latitude->[0]  - LATITUDE_MAX,
        $longitude->[0] - LONGITUDE_MAX,
        $latitude->[1]  - LATITUDE_MAX,
        $longitude->[1] - LONGITUDE_MAX,
        length($code),
    );
}

sub _decode_pairs_sequence {
    my ($code, $offset) = @_;

    my $i = 0;
    my $value = 0;

    while ($i * 2 + $offset < length($code)) {
        $value += index(CODE_ALPHABET, substr($code, $i * 2 + $offset, 1)) * PAIR_RESOLUTIONS->[$i];
        $i++;
    }

    return [$value, $value + PAIR_RESOLUTIONS->[$i - 1]];
}

sub _decode_grid {
    my $code = shift;

    my $latitude_lo = 0.0;
    my $longitude_lo = 0.0;
    my $lat_place_value = GRID_SIZE_DEGREES;
    my $lng_place_value = GRID_SIZE_DEGREES;
    my $i = 0;

    while ($i < length($code)) {
        my $code_index = index(CODE_ALPHABET, substr($code, $i, 1));
        my $row = floor($code_index / GRID_COLUMNS);
        my $col = $code_index % GRID_COLUMNS;

        $lat_place_value = $lat_place_value / GRID_ROWS;
        $lng_place_value = $lng_place_value / GRID_COLUMNS;

        $latitude_lo += $row * $lat_place_value;
        $longitude_lo += $col * $lng_place_value;
        $i++
    }

    return Geo::OpenLocationCode::CodeArea->new(
        $latitude_lo,
        $longitude_lo,
        $latitude_lo + $lat_place_value,
        $longitude_lo + $lng_place_value,
        length($code)
    );
}

1;

package Geo::OpenLocationCode::CodeArea;
use List::Util qw/min/;

sub new {
    my $class = shift;
    my ($latitude_lo, $longitude_lo, $latitude_hi, $longitude_hi, $code_length) = @_;

    bless {
        latitude_lo      => $latitude_lo,
        longitude_lo     => $longitude_lo,
        latitude_hi      => $latitude_hi,
        longitude_hi     => $longitude_hi,
        code_length      => $code_length,
        latitude_center  => min($latitude_lo + ($latitude_hi - $latitude_lo) / 2, Geo::OpenLocationCode::LATITUDE_MAX()),
        longitude_center => min($longitude_lo + ($longitude_hi - $longitude_lo) / 2, Geo::OpenLocationCode::LONGITUDE_MAX()),
    }, $class;
}

sub latitude_lo {
    $_[0]->{latitude_lo};
}

sub longitude_lo {
    $_[0]->{longitude_lo};
}

sub latitude_hi {
    $_[0]->{latitude_hi};
}

sub longitude_hi {
    $_[0]->{longitude_hi};
}

sub code_length {
    $_[0]->{code_length};
}

sub latitude_center : lvalue {
    $_[0]->{latitude_center};
}

sub longitude_center : lvalue {
    $_[0]->{longitude_center};
}

1;

__END__

=encoding utf-8

=head1 NAME

Geo::OpenLocationCode - Encode / Decode Open Location Codes.

=head1 SYNOPSIS

    use Geo::OpenLocationCode;

    encode(35.6292765,139.7939337);      # 8Q7XJQHV+PH
    encode(35.6292765,139.7939337, 12);  # 8Q7XJQHV+PH75

    my $area = decode('8Q7XJQHV+QF');
    $area->code_length;       # 10
    $area->latitude_center;   # 35.6293125
    $area->latitude_hi;       # 35.629375
    $area->latitude_lo;       # 35.62925
    $area->longitude_center;  # 139.7939375
    $area->longitude_hi;      # 139.794
    $area->longitude_lo;      # 139.793875

=head1 DESCRIPTION

Open Location Codes are a way of encoding location into a form that is easier to use than latitude and longitude.

This module encodes and decodes Open Location Codes.

See http://openlocationcode.com/ for more information.

=head1 METHODS

=head2 encode

Encode a location into an Open Location Code. This takes a latitude and
longitude and an optional length. If the length is not specified, a code
with 10 characters (excluding the prefix and separator) will be generated.

    encode(35.6292765, 139.7939337);      # 8Q7XJQHV+PH
    encode(35.6292765, 139.7939337, 12);  # 8Q7XJQHV+PH75

=head2 decode

Decodes an Open Location Code into the location coordinates. This method
takes a string. If the string is a valid full Open Location Code, it
returns an object with the lower and upper latitude and longitude pairs,
the center latitude and longitude, and the length of the original code.

    my $area = decode('8Q7XJQHV+QF');

    $area->code_length;       # 10
    $area->latitude_center;   # 35.6293125
    $area->latitude_hi;       # 35.629375
    $area->latitude_lo;       # 35.62925
    $area->longitude_center;  # 139.7939375
    $area->longitude_hi;      # 139.794
    $area->longitude_lo;      # 139.793875

=head2 shorten

Remove the first four to eight characters from a valid full
Open Location Code and a latitude and longitude. The number
of characters that can be removed depends on the distance
between the code center and the reference location.

    shorten('9C3W9QCJ+2VX', 51.3701125, -1.217765625); # +2VX
    shorten('9C3W9QCJ+2VX', 51.3708675, -1.217765625); # CJ+2VX
    shorten('9C3W9QCJ+2VX', 51.3852125, -1.217765625); # 9QCJ+2VX

=head2 recover_nearest

Returns the nearest matching full Open Location Code from a
valid short Open Location Code (of four to seven characters)
and a latitude and longitude.

    recover_nearest('+2VX', 51.3701125, -1.217765625);     # 9C3W9QCJ+2VX
    recover_nearest('9QCJ+2VX', 51.3852125, -1.217765625); # 9C3W9QCJ+2VX

=head2 is_valid

Determines if a code is a valid Open Location Code sequence.

    is_valid('8FWC2345+G6'); # 1
    is_valid('8FWC2345+G');  # 0

=head2 is_short

Determines if a code is a valid short Open Location Code.

    is_short('+G6');       # 1
    is_short('8FWCX400+'); # 0

=head2 is_full

Determines if a code is a valid full Open Location Code.

    is_full('8FWC2345+G6'); # 1
    is_full('2345+G6');     # 0

=head1 SEE ALSO

https://github.com/google/open-location-code/blob/master/API.txt

=head1 LICENSE

Copyright (C) nkwhr.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

nkwhr E<lt>naoya.kawahara[at]gmail.comE<gt>

=cut
