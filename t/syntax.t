use strict;
use warnings;

BEGIN {
    use Test::Compile tests => 12;
}

pm_file_ok($_) for map "lib/Git/CPAN/$_", qw# Patch.pm Patch/Import.pm #;

pl_file_ok( $_ ) for <scripts/*>;



