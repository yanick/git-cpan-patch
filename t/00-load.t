#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Language::l33t' );
}

diag( "Testing Language::l33t $Language::l33t::VERSION, Perl $], $^X" );
