package Git::CPAN::Patch::Command::Sources;
#ABSTRACT: lists sources for the module

use 5.10.0;

use strict;
use warnings;
use List::Pairwise qw/ mapp /;

use MooseX::App::Command;

with 'Git::CPAN::Patch::Role::Git';

use experimental qw/
    signatures
    postderef
/;

option repository => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
    trigger => sub ($self) {
        return unless $self->repository;
        $self->set_cpan(0);
        $self->set_backpan(0);
    },
    documentation => 'show repository information',
);

option cpan => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
    trigger => sub ($self) {
        return unless $self->cpan;
        $self->set_repository(0);
        $self->set_backpan(0);
    },
    documentation => 'show cpan information',
);

option backpan => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
    trigger => sub ($self) {
        return unless $self->backpan;
        $self->set_repository(0);
        $self->set_cpan(0);
    },
    documentation => 'show backpan information',
);

parameter thingy => (
    is  => 'rw',
    isa => 'Str',
);

sub release_meta ($self, $thingy) {
    require MetaCPAN::Client;
    my $mcpan = MetaCPAN::Client->new;

    eval { $mcpan->release( $mcpan->module($thingy)->distribution ) }
    || eval { $mcpan->release( $thingy ) }
    || die "could not find release for '$thingy' on metacpan\n";
}

sub run ($self) {
    if ( $self->backpan ) {
        say "backpan:";

        require MetaCPAN::Client;
        my $mcpan = MetaCPAN::Client->new;

        my $releases = $mcpan->release(
            { distribution => $self->thingy },
            { sort => [{ date => { order => 'asc' } }] },
        );

        if (!$releases->total) {
            die "could not find releases for '$self->thingy' on metacpan\n";
        }

        while (my $release = $releases->next) {
            say "  - ", $release->download_url;
        }

        return;
    }

    my $meta = $self->release_meta($self->thingy);

    if ( $self->repository and $meta->resources->{repository} ) {
        say "vcs:";
        mapp { say "  $a: $b" } %{ $meta->resources->{repository} };
    }
    if ( $self->cpan ) {
        say "cpan:";
        for ( qw/ download_url / ) {
            say "  $_: ", $meta->$_;
        }
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
