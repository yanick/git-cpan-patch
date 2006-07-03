use strict;
use warnings;

use Test::More tests => 6;                      # last test to print

use Language::l33t;

{
local *STDERR;
my $errors;
open STDERR, '+>', \$errors;

# test the error message if the program is bigger than 
# the memory size
my $l33t = Language::l33t->new({ memory_size => 10 });

is $l33t->load( join ' ', 1..9 ) => 1, 'program within the memory size';
is $errors => undef, 'program within the memory size';

is $l33t->load( join ' ', 1..10 ) => 0, 'program outside the memory size';
is $errors => "F00l! teh c0d3 1s b1g3R th4n teh m3m0ry!!1!\n", 'program outside the memory size';
}

# test if the byte size is respected, by default

my $output;
open my $fh_output, '>', \$output;
my $l33t = Language::l33t->new({ stdout => $fh_output });

$l33t->load( '7 '.( '9'x( 256/9 ) ).' 7 7 1 5o5' );
$l33t->run;
my $expected = ( 9*int( 256/9 ) + 9 ) % 256;
is ord($output) => $expected, 'default byte size';

# test if the byte size is respected, if different than default

close $fh_output;
$output = undef;
open $fh_output, '>', \$output;
$l33t = Language::l33t->new({ stdout => $fh_output,
                          byte_size => 11 });

$l33t->load( '7 9 7 1 1 5o5' );
$l33t->run;

is ord( $output ), 1, 'byte size';
