use strict;
use warnings;

use Test::More tests => 2;                      # last test to print

BEGIN {
    use_ok 'Git::CPAN::Patch';
    use_ok 'Git::CPAN::Patch::Import';
}
