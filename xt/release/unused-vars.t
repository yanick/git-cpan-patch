use Test::More 0.96 tests => 1;
use Test::Vars;

subtest 'unused vars' => sub {
all_vars_ok();
};
