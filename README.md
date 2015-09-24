# NAME

Geo::OpenLocationCode - Encode / Decode Open Location Codes.

# SYNOPSIS

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

# DESCRIPTION

Open Location Codes are a way of encoding location into a form that is easier to use than latitude and longitude.

This module encodes and decodes Open Location Codes.

See http://openlocationcode.com/ for more information.

# METHODS

## encode

Encode a location into an Open Location Code. This takes a latitude and
longitude and an optional length. If the length is not specified, a code
with 10 characters (excluding the prefix and separator) will be generated.

    encode(35.6292765, 139.7939337);      # 8Q7XJQHV+PH
    encode(35.6292765, 139.7939337, 12);  # 8Q7XJQHV+PH75

## decode

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

## shorten

Remove the first four to eight characters from a valid full
Open Location Code and a latitude and longitude. The number
of characters that can be removed depends on the distance
between the code center and the reference location.

    shorten('9C3W9QCJ+2VX', 51.3701125, -1.217765625); # +2VX
    shorten('9C3W9QCJ+2VX', 51.3708675, -1.217765625); # CJ+2VX
    shorten('9C3W9QCJ+2VX', 51.3852125, -1.217765625); # 9QCJ+2VX

## recover\_nearest

Returns the nearest matching full Open Location Code from a
valid short Open Location Code (of four to seven characters)
and a latitude and longitude.

    recover_nearest('+2VX', 51.3701125, -1.217765625);     # 9C3W9QCJ+2VX
    recover_nearest('9QCJ+2VX', 51.3852125, -1.217765625); # 9C3W9QCJ+2VX

## is\_valid

Determines if a code is a valid Open Location Code sequence.

    is_valid('8FWC2345+G6'); # 1
    is_valid('8FWC2345+G');  # 0

## is\_short

Determines if a code is a valid short Open Location Code.

    is_short('+G6');       # 1
    is_short('8FWCX400+'); # 0

## is\_full

Determines if a code is a valid full Open Location Code.

    is_full('8FWC2345+G6'); # 1
    is_full('2345+G6');     # 0

# SEE ALSO

https://github.com/google/open-location-code/blob/master/API.txt

# LICENSE

Copyright (C) nkwhr.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

nkwhr <naoya.kawahara\[at\]gmail.com>
