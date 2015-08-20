use strict;
use Test::More;

BEGIN {
    use_ok 'Geo::OpenLocationCode';
}

my @valid_codes = qw/8FWC2345+G6 8FWC2345+G6G 8fwc2345+ 8FWCX400+/;
my @valid_short_codes = qw/WC2345+G6g 2345+G6 45+G6 +G6/;
my @invalid_codes = qw/G+ + 8FWC2345+G 8FWC2_45+G6 8FWC2η45+G6 8FWC2345+G6+ 8FWC2300+G6 WC2300+G6g WC2345+G/;

subtest 'is_valid' => sub {
    ok is_valid($_),  "$_ is valid"   for @valid_codes;
    ok is_valid($_),  "$_ is valid"   for @valid_short_codes;
    ok !is_valid($_), "$_ is invalid" for @invalid_codes;
};

subtest 'is_short' => sub {
    ok !is_short($_), "$_ isn't short" for @valid_codes;
    ok is_short($_),  "$_ is short"    for @valid_short_codes;
    ok !is_short($_), "$_ is invalid"  for @invalid_codes;
};

subtest 'is_full' => sub {
    ok is_full($_),  "$_ is full"    for @valid_codes;
    ok !is_full($_), "$_ isn't full" for @valid_short_codes;
    ok !is_full($_), "$_ is invalid" for @invalid_codes;
};

done_testing;
