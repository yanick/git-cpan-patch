package Git::CPAN::Patch::Command::sources;
BEGIN {
  $Git::CPAN::Patch::Command::sources::AUTHORITY = 'cpan:YANICK';
}
{
  $Git::CPAN::Patch::Command::sources::VERSION = '0.8.0';
}

use 5.10.0;

use strict;
use warnings;

use Moose;
use DateTime::Format::W3CDTF;

extends 'MooseX::App::Cmd::Command';

has '+app' => (
    handles => [ qw/ set_target distribution_meta / ],
);

sub execute {
    my ( $self, $opts, $args ) = @_;

    die "usage: git cpan-sources <distribution>\n" unless $args->[0];

    $self->set_target( $args->[0] );
    my $meta = $self->distribution_meta;

    if ( my $repo = $meta->{resources}{repository} ) {
        say "Repository";
        for ( qw/ type url web / ) {
            say "\t$_: ", $repo->{$_} if $repo->{$_};
        }
        say "\n";
    };

    say "CPAN";
    my $date = DateTime::Format::W3CDTF->new->parse_datetime( $meta->{date} );
    say "\tlatest release: ", $meta->{version}, " (",  $date->ymd, ")";
    say "\turl: ", $meta->{download_url};


}


1;

__END__
