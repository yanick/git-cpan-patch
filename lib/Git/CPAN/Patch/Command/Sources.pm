package Git::CPAN::Patch::Command::Sources;
BEGIN {
  $Git::CPAN::Patch::Command::Sources::AUTHORITY = 'cpan:YANICK';
}
{
  $Git::CPAN::Patch::Command::Sources::VERSION = '1.2.0';
}
#ABSTRACT: lists sources for the module

use 5.10.0;

use strict;
use warnings;

use Method::Signatures::Simple;
use List::Pairwise qw/ mapp /;

use MooseX::App::Command;

with 'Git::CPAN::Patch::Role::Git';

option repository => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
    trigger => method {
        return unless $self->vcs;
        $self->set_cpan(0);
        $self->set_backpan(0);
    },
    documentation => 'show repository information',
);

option cpan => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
    trigger => method {
        return unless $self->cpan;
        $self->set_vcs(0);
        $self->set_backpan(0);
    },
    documentation => 'show cpan information',
);

option backpan => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
    trigger => method {
        return unless $self->backpan;
        $self->set_vcs(0);
        $self->set_cpan(0);
    },
    documentation => 'show backpan information',
);

parameter thingy => (
    is  => 'rw',
    isa => 'Str',
);

has release_meta => (
    is => 'ro',
    lazy => 1,
    default => method {
        require MetaCPAN::API;
        my $mcpan = MetaCPAN::API->new;

        my $thingy = $self->thingy;

        eval { $mcpan->release( 
                distribution => $mcpan->module($thingy)->{distribution}
        ) }
        || eval { $mcpan->release( distribution => $thingy ) }
        || die "could not find release for '$thingy' on metacpan\n";
    },
);

has backpan_index => (
    is => 'ro',
    lazy => 1,
    default => sub {
        require BackPAN::Index;
        return BackPAN::Index->new;
    },
);

method run {
    if ( $self->repository and $self->release_meta->{resources}{repository} ) {
        say "vcs:";
        mapp { say "  $a: $b" } %{ $self->release_meta->{resources}{repository} };
    }

    if ( $self->cpan ) {
        say "cpan:";
        for ( qw/ download_url / ) {
            say "  $_: ", $self->release_meta->{$_};
        }
    }

    my $BackPAN_URL = "http://backpan.perl.org/";
    if ( $self->backpan ) {
        say "backpan:";
        my $dist = $self->backpan_index->dist($self->thingy)
            or die "could not find distribution on BackPAN";

        say "  - ", $BackPAN_URL . "/" . $_->prefix 
            for $dist->releases->search( undef, { order_by => "date" } )->all;
    }
}


__PACKAGE__->meta->make_immutable;

1;

__END__


use Moose;
use DateTime::Format::W3CDTF;

extends 'MooseX::App::Cmd::Command';

has '+app' => (
    handles => [ qw/ set_target distribution_meta / ],
);

sub execute {
    my ( $self, $opts, $args ) = @_;

    die "usage: git-cpan sources <distribution>\n" unless $args->[0];

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

=head1 SYNOPSIS

    % git-cpan sources Foo::Bar

=cut
