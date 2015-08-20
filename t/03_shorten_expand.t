use strict;
use Test::More;
use File::Basename;
use Cwd;

BEGIN {
    use_ok 'Geo::OpenLocationCode';
}

my @test_data;
my $dir = dirname(Cwd::realpath(__FILE__));

open my $fh, '<', "$dir/test_data/shorten_expand_tests.csv"
    or die "Can't open test data";

while (my $line = <$fh>) {
    chomp $line;
    my @fields = split ',', $line;
    push @test_data, {
        full_code  => $fields[0],
        lat        => $fields[1] + 0,
        lng        => $fields[2] + 0,
        short_code => $fields[3],
    };
}

close $fh;

subtest 'recover_nearest' => sub {
    for my $t (@test_data) {
        is recover_nearest($t->{short_code}, $t->{lat}, $t->{lng}), $t->{full_code},
            "$t->{short_code}, $t->{lat}, $t->{lng} => $t->{full_code}";
    }
};

subtest 'shorten' => sub {
    for my $t (@test_data) {
        is shorten($t->{full_code}, $t->{lat}, $t->{lng}), $t->{short_code},
            "$t->{full_code}, $t->{lat}, $t->{lng} => $t->{short_code}";
    }
};

done_testing;
