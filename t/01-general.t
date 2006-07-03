use strict;
use warnings;

use Test::More tests => 6;

use Language::l33t;

my $output;
open my $fh_output, '>', \$output;

my $l33t = Language::l33t->new({ stdout => $fh_output });

$l33t->load( '7 75 55' );
$l33t->run;
is( join( ':', $l33t->get_memory ), '7:12:10:13', 'INC' );

$l33t->load( '8 75 55' );
$l33t->run;
is( join( ':', $l33t->get_memory ), '8:12:10:243', 'DEC' );

{
    local *STDERR;

    my $errors;
    open STDERR, '>', \$errors;

    $l33t->load( '777 55' );
    $l33t->run;

    is $errors, "j00 4r3 teh 5ux0r\n", 'error if opCode > 10';

    close STDERR;
    $errors = '';
    open STDERR, '>', \$errors;

    $l33t->load( '6 5 9 55 999999999999991 0 0 1 999999998 999999998' );
    $l33t->run;

    is $errors, "h0s7 5uXz0r5! c4N'7 c0Nn3<7 101010101 l4m3R !!!\n",
        'error if connect to invalid socket';

    open STDERR, '>', \$errors;

    # try to run without load first? 
    $l33t = Language::l33t->new();
    $l33t->run;

    like $errors => qr/^L0L!!1!1!! n0 l33t pr0gr4m l04d3d, sUxX0r!/,
        'run()ning before load()ing a program';

}

$l33t->load( '3 5o5' );
eval { $l33t->run; };

like $@ => qr/dud3, wh3r3's my EIF?/, 'IF without EIF';


