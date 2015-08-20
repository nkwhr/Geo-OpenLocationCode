use strict;
use Test::More;
use File::Basename;
use Cwd;

BEGIN {
    use_ok 'Geo::OpenLocationCode';
}

my @test_data;
my $dir = dirname(Cwd::realpath(__FILE__));

open my $fh, '<', "$dir/test_data/encode_decode_tests.csv"
    or die "Can't open test data";

while (my $line = <$fh>) {
    chomp $line;
    my @fields = split ',', $line;
    push @test_data, {
        code   => $fields[0],
        lat    => $fields[1] + 0,
        lng    => $fields[2] + 0,
        lat_lo => $fields[3] + 0,
        lng_lo => $fields[4] + 0,
        lat_hi => $fields[5] + 0,
        lng_hi => $fields[6] + 0
    };
}

close $fh;

subtest 'decode' => sub {
    for my $t (@test_data) {
        my $code_area = decode($t->{code});

        ok close_enough($t->{lat_lo}, $code_area->latitude_lo),
            "lat lo : $t->{lat_lo} (approx) equals to " . $code_area->latitude_lo;

        ok close_enough($t->{lng_lo}, $code_area->longitude_lo),
            "lng lo : $t->{lng_lo} (approx) equals to " . $code_area->longitude_lo;

        ok close_enough($t->{lat_hi}, $code_area->latitude_hi),
            "lat hi : $t->{lat_hi} (approx) equals to " . $code_area->latitude_hi;

        ok close_enough($t->{lng_hi}, $code_area->longitude_hi),
            "lng hi : $t->{lng_hi} (approx) equals to " . $code_area->longitude_hi;
    }
};

subtest 'encode' => sub {
    for my $t (@test_data) {
        my $code_area = decode($t->{code});
        my $code = encode($t->{lat}, $t->{lng}, $code_area->code_length);
        is $code, $t->{code}, "$t->{code} => (decode/encode) => $code";
    }
};

sub close_enough {
    my ($a, $b) = @_;
    $a == $b || abs($a - $b) <= 0.0000000001;
}

done_testing;
