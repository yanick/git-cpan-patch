package Language::l33t;

use strict;
use warnings;
use Carp;

use Class::Std;
use Readonly;
use IO::Socket::INET;

our $VERSION = '0.03';

my %debug           : ATTR( :name<debug> :default(0) );
my %code_of         : ATTR( :name<code> :default('') );
                                                      # 64 * 1024
my %memory_size_of  : ATTR( :init_arg<memory_size> :default(65536) );      
my %byte_size_of    : ATTR( :init_arg<byte_size> :default(256) );
my %memory_of       : ATTR;
my %mem_ptr_of      : ATTR;
my %op_ptr_of       : ATTR;
my %stdout_of       : ATTR( :name<stdout> :default(0) );
my %stdin_of        : ATTR( :name<stdin> :default(0) );
my %socket_of       : ATTR;

my @op_codes;

Readonly my $NOP => 0;
Readonly my $WRT => 1;
Readonly my $RD  => 2;
Readonly my $IF  => 3;
Readonly my $EIF => 4;
Readonly my $FWD => 5;
Readonly my $BAK => 6;
Readonly my $INC => 7;
Readonly my $DEC => 8;
Readonly my $CON => 9;
Readonly my $END => 10;

$op_codes[$NOP] = \&_nop;
$op_codes[$WRT] = \&_wrt;
$op_codes[$RD]  = \&_rd;
$op_codes[$IF]  = \&_if;
$op_codes[$EIF] = \&_eif;
$op_codes[$FWD] = \&_fwd;
$op_codes[$BAK] = \&_bak;
$op_codes[$INC] = \&_inc;
$op_codes[$DEC] = \&_dec;
$op_codes[$CON] = \&_con;
$op_codes[$END] = \&_end;

sub START {
    my( $self, $id ) = @_;

    if ( $byte_size_of{ $id } <= 10 ) {
        local $Carp::CarpLevel = 1;
        croak "Byt3 s1z3 must be at l34st 11, n00b!";
    }
}

sub initialize {
    my $self = shift;
    my $id = ident $self;

    # final zero for the initial memory
    my @memory = (  map ( { my $s = 0; 
                        $s += $& while /\d/g; 
                        $s % $byte_size_of{ $id } 
                      } split ' ', $code_of{ $id } ), 0 );

    if ( $memory_size_of{ $id } < @memory ) {
        warn "F00l! teh c0d3 1s b1g3R th4n teh m3m0ry!!1!\n"; 
        return 0;
    }

    $op_ptr_of{ $id } = 0;
    $mem_ptr_of{ $id } = $#memory;

    $memory_of{ $id } = \@memory;

    if( $debug{ $id } ) {
        warn "compiled memory: ", join( ':', @{$memory_of{$id}} ), "\n";
    }

    return 1;
}

sub get_memory {
    my $self = shift;
    my $id = ident $self;

    return @{ $memory_of{ $id } };
}

sub load {
    my( $self, $code ) = @_;
    my $id = ident $self;

    $code_of{ $id } = $code;

    if( $debug{ $id } ) {
        warn "code: $code\n";
    }

    return $self->initialize;
}

sub run {
    my $self = shift;
    my $nbr_iterations = shift || -1;
    my $id = ident $self;

    unless ( defined $memory_of{ $id } ) {
       carp 'L0L!!1!1!! n0 l33t pr0gr4m l04d3d, sUxX0r!';
       return 0;
    }
  
    while ( $self->_iterate ) {
        $nbr_iterations-- if $nbr_iterations != -1;
        return 1 unless $nbr_iterations;
    }

    return 0;
}

sub _iterate {
    my $self = shift;
    my $id = ident $self;
    my $op_id = $memory_of{ $id }[ $op_ptr_of{ $id } ]; 
 
    if ( $debug{ $id } ) { 
        no warnings qw/ uninitialized /;
        warn "memory: ", join( ':', @{$memory_of{$id}} ), "\n";
        warn "op_ptr: $op_ptr_of{ $id }, ",
                "mem_ptr: $mem_ptr_of{ $id }, ",
                "op: $op_id, ",
                "mem: ", $self->_get_current_mem, "\n";
    }

    warn "j00 4r3 teh 5ux0r\n" if $op_id > 10;

    if ( my $op = $op_codes[ $op_id ] ) {
        return $op_codes[ $op_id ]->( $self );
    }
    else {
        return $self->_nop;
    }
}

sub _nop {
    my $self = shift;
    $self->_incr_op_ptr;
    return 1;
}

sub _end {
    my $self = shift;
    return 0;
}

sub _incr_op_ptr {
    my $self = shift;
    my $increment = shift || 1;
    my $id = ident $self;

    $op_ptr_of{ $id } += $increment;
}

sub _incr_mem_ptr {
    my $self = shift;
    my $increment = shift || 1;
    my $id = ident $self;

    $mem_ptr_of{ $id } += $increment;
}

sub _incr_mem {
    my $self = shift;
    my $increment = shift;
    my $id = ident $self;

    $memory_of{ $id }[ $mem_ptr_of{ $id } ] += $increment;
    $memory_of{ $id }[ $mem_ptr_of{ $id } ] %= $byte_size_of{ $id };
}

sub _inc {
    my $self = shift;
    my $sign = shift || 1;
    my $id = ident $self;

    $self->_incr_op_ptr;
    $self->_incr_mem( $sign * ( 1 + $memory_of{ $id }[ $op_ptr_of{ $id } ] ) );
    $self->_incr_op_ptr;
    return 1;
}

sub _dec {
    my $self = shift;
    $self->_inc( -1 );

    return 1;
}

sub _set_current_mem {
    my $self = shift;
    my $id = ident $self;

    croak( "_set_current_mem requires one argument" ) unless @_;

    return $memory_of{ $id }[ $mem_ptr_of{$id} ] = shift;
}

sub _get_current_mem {
    my $self = shift;
    my $id = ident $self;

    return $memory_of{ $id }[ $mem_ptr_of{$id} ];
}

sub _current_op {
    my $self = shift;
    my $id = ident $self;

    return $memory_of{ $id }[ $op_ptr_of{$id} ] || 0;
}

sub _if {
    my $self = shift;
    my $id = ident $self;

    if ( $self->_get_current_mem ) {
        $self->_nop;
    }
    else {
        my $nest_level = 0;
        my $max_iterations = $memory_size_of{ $id };

        SCAN:
        while (1) {
            $self->_incr_op_ptr;
            $max_iterations--;

            $nest_level++ and redo if $self->_current_op == $IF;

            if ( $self->_current_op == $EIF ) {
                if ( $nest_level ) {
                    $nest_level--;
                }
                else {
                    break SCAN;        
                }
            }

            unless ( $max_iterations ) {
                croak "dud3, wh3r3's my EIF?";
            }
            
        }
    }

    return 1;
}

sub _eif {
    my $self = shift;
    my $id = ident $self;

    if ( ! $self->_get_current_mem ) {
        $self->_nop;
    }
    else {
        $self->_incr_op_ptr( -1 ) until $self->_current_op == 3;
    };

    return 1;
}

sub _fwd {
    my $self = shift;
    my $direction = shift || 1;
    my $id = ident $self;

    $self->_incr_op_ptr;
    $self->_incr_mem_ptr( $direction * ( 1 + $self->_current_op )  );
    $self->_incr_op_ptr;

    return 1;
}

sub _bak { $_[0]->_fwd( -1 ); return 1; }

sub _wrt { 
    my $self = shift;
    my $id = ident $self;

    if ( my $io = $socket_of{ $id } || $stdout_of{ $id } ) {
        no warnings qw/ uninitialized /;
        print {$io} chr $self->_get_current_mem;
    }
    else {
        print chr $self->_get_current_mem;
    }
    $self->_incr_op_ptr;

    return 1;
}

sub _rd {
    my $self = shift;
    my $id = ident $self;

    my $chr;

    if ( my $io = $socket_of{ $id } || $stdin_of{ $id } ) {
        read $io, $chr, 1;
    }
    else {
        read STDIN, $chr, 1;
    }

    $self->_set_current_mem( ord $chr );
    $self->_incr_op_ptr;

    return 1;
}

sub _con {
    my $self = shift;
    my $id = ident $self;

    my $ip = join '.', map { 
                            my $x = $self->_get_current_mem; 
                            $self->_incr_mem_ptr;
                            $x || 0;
                           } 1..4;

    my $port = ( $self->_get_current_mem() || 0 ) << 8;
    $self->_incr_mem_ptr;
    {
        no warnings qw/ uninitialized /;
        $port += $self->_get_current_mem;
    }

    $self->_incr_mem_ptr( -5 );

    warn "trying to connect at $ip:$port\n" 
        if $debug{ $id };

    if ( "$ip:$port" eq '0.0.0.0:0' ) {
        $socket_of{ $id } = undef;
    }
    else {
        if ( my $sock = IO::Socket::INET->new( "$ip:$port" ) ) {
            $socket_of{ $id } = $sock;
        } 
        else {
            warn "h0s7 5uXz0r5! c4N'7 c0Nn3<7 101010101 l4m3R !!!\n";
        }
    }

    $self->_incr_op_ptr;
    return 1;
}

1; # End of Language::l33t

__END__

=head1 NAME

Language::l33t - a l33t interpreter

=head1 SYNOPSIS

    use Language::l33t;

    my $interpreter = Language::l33t->new;
    $interpreter->load( 'Ph34r my l33t sk1llz' );
    $interpreter->run;

=head1 DESCRIPTION

Language::l33t is a Perl interpreter of the l33t language created by
Stephen McGreal and Alex Mole. For the specifications of l33t, refer
to the REFERENCE section.

=head1 METHODS

=head2 new( \%options )

Creates a new interpreter. The options that can be passed to the function are:

=over

=item debug => $flag

If $flag is set to true, the interpreter will print debugging information
as it does its thing.

=item stdin => $io

=item stdout => $io

Ties the stdin/stdout of the interpreter to the given object. 

E.g.:

    my $output;
    open my $fh_output, '>', \$output;

    my $l33t = Language::l33t->new({ stdout => $fh_output });

    $l33t->load( $code );
    $l33t->run;

    print "l33t output: $output";

=item memory_size => $bytes

The size of the block of memory used by the interpreter. By default set to
64K (as the specs recomment).

=item byte_size => $size

The size of a byte in the memory used by the interpreter. Defaults to
256 (so a memory byte can hold a value going from 0 to 255).



=back

=head2 load( $l33tcode )

Loads and "compiles" the string $l33tcode. If one program was already loaded,
it is clobbered by the newcomer. Returns 1 upon success, 0 if the loading
failed.

=head2 run( [ $nbr_iterations ] )

Runs the loaded program. If $nbr_iterations is given, interupts the program
after this number of iterations even if it hasn't terminated. Returns 0 in
case the program terminated by evaluating an END, 1 if it finished by reaching
$nbr_iterations.

=head2 initialize

Initializes, or reinitializes the interpreter to its initial setting. Code is
recompiled, and pointers reset to their initial values. Implicitly called when
new code is load()ed. 

Returns 1 upon success, 0 if something went wrong.

E.g.

    my $l33t = Language::l33t->new();
    $l33t->load( $code );
    $l33t->run;

    # to run the same code a second time
    $l33t->initialize;
    $l33t->run;


=head2 get_memory

Returns the memory of the interpreter in its current state as an array.

=head1 DIAGNOSTICS

=over

=item F00l! teh c0d3 1s b1g3R th4n teh m3m0ry!!1!

You tried to load a program that is too big to fit in 
the memory. Note that at compile time, one byte is reserved
for the memory buffer, so the program's size must be less than
the memory size minus one byte.

=item Byt3 s1z3 must be at l34st 11, n00b!

The I<byte_size> argument of I<new()> was less than 11. 
The byte size of an interpreter must be at least 11 (to
accomodate for the opcodes).

=item L0L!!1!1!! n0 l33t pr0gr4m l04d3d, sUxX0r!

run() called before any program was load()ed.

=back

=head1 BUGS

Please report any bugs or feature requests to
C<bug-acme-l33t at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Language::l33t>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Language::l33t

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Language::l33t>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Language::l33t>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Language::l33t>

=item * Search CPAN

L<http://search.cpan.org/dist/Language::l33t>

=back

=head1 REFERENCES

Stephen McGreal's l33t page: http://electrod.ifreepages.com/l33t.htm

Wikipedia article on l33t: http://en.wikipedia.org/wiki/L33t_programming_language

=head1 AUTHOR

Yanick Champoux, C<< <yanick at cpan.org> >>

=head1 THANKS 

It goes without saying, special thanks go 
to Stephen McGreal and Alex Mole for inventing l33t. 
They are teh rOxX0rs.

=head1 COPYRIGHT & LICENSE

Copyright 2006 Yanick Champoux, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

