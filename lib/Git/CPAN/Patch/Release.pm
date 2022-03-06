package Git::CPAN::Patch::Release;
our $AUTHORITY = 'cpan:YANICK';
$Git::CPAN::Patch::Release::VERSION = '2.5.0';
use strict;
use warnings;
use File::chdir;
use Archive::Any;
use Path::Tiny;
use File::Temp qw/ tempdir tempfile /;
use version;

use Moose;

use experimental qw/
    signatures
    postderef
/;

has tmpdir => (
  is => 'ro',
  isa => 'Path::Tiny',
  lazy => 1,
  default => sub {
    return Path::Tiny->tempdir();
  }
);

has author_name => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;

        if ( $self->meta_info ) {
            my $author = $self->meta_info->{metadata}{author};
            $author = $author->[0] if ref $author;

            if ( !$author or  $author eq 'unknown' ) {
                $author = $self->meta_info->{author};
            }

            return $author =~ /^\s*(.*?)\s*</ ? $1 : $author if $author;
        }

        return $self->author_cpan || 'unknown';
    },
);

has author_cpan => (
    is => 'ro',
    isa => 'Maybe[Str]',
    lazy => 1,
    default => sub {
        my $author = eval{$_[0]->meta_info->{author}};
        $author = ref $author ? $author->[0] : $author;
        $author = uc($1) if $author =~ /<?(\S+)\@cpan\.org/i;
        return $author;
    },
);

has author_email => (
    is => 'ro',
    isa => 'Maybe[Str]',
    predicate => 'has_author_email',
    lazy => 1,
    default => sub {
        my $self = shift;

        if ( $self->meta_info ) {
            my $author = $self->meta_info->{metadata}{author} || $self->meta_info->{author};
            $author = $author->[0] if ref $author;
            return $1 if $author =~ /<(.*?)>\s*$/;
        }
        return $self->author_cpan . '@cpan.org';
    },
);

sub author_sig {
    my $self = shift;

    return sprintf "%s <%s>", $self->author_name, $self->author_email;
}

has download_url => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->meta_info && $self->meta_info->{download_url};
    },
);

has date => (
    is => 'ro',
    isa => 'Maybe[Str]',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->meta_info && $self->meta_info->{date};
    },
);

has version => (
    is => 'ro',
    isa => 'Str',
);

has tarball => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        if ( $self->download_url ) {

            my( undef, $file ) = tempfile();
            $file .= ".tar.gz";

            if ( $self->download_url =~ /^(?:ht|f)tp/ ) {
                require LWP::Simple;
                LWP::Simple::getstore( $self->download_url => $file )
                    or die "could not retrieve ", $self->download_url, "\n";
            }
            else {
                require File::Copy;

                File::Copy::copy( $self->download_url => $file );
            }

            return $file;
        }

        return undef;
    },
);

has extracted_dir => (
    is => 'ro',
    lazy => 1,
    default => sub($self) {

        my $archive = Archive::Any->new( $self->tarball );
        my $tmpdir = $self->tmpdir;
        $archive->extract( $tmpdir );

        return $tmpdir if $archive->is_impolite;

        my $dir;
        opendir $dir, $tmpdir;
        my( $sub ) = grep { !/^\.\.?$/ } readdir $dir;

        return join '/', $tmpdir, $sub;
    },
);

has cpan_parse => (
    is => 'ro',
    predicate => 'has_cpan_parse',
    lazy => 1,
    default => sub($self) {
        require CPAN::ParseDistribution;
        CPAN::ParseDistribution->new( $self->tarball );
    },
);

has metacpan => (
    is => 'ro',
    lazy => 1,
    default => sub {
        require MetaCPAN::Client;
        MetaCPAN::Client->new;
    }
);

has meta_info => (
    is => 'ro',
    lazy => 1,
    predicate => 'has_meta_info',
    default => sub($self) {
        require MetaCPAN::Client;

        if( my $release = $self->metacpan->release({ all =>
                    [
                        { distribution => $self->dist_name },
                        { version => $self->dist_version },
                    ]
                }) ) {
                $release = $release->next;
                return $release->data if $release;
            }

        # TODO check on cpan if the info is not there

        require CPAN::Meta;

        my( $result ) = map { CPAN::Meta->load_file($_) }
                        grep { $_->exists }
                        map { path( $self->extracted_dir )->child( "META.$_" ) } qw/ json yml /;

        return $result;

    },
);

has dist_version => (
    is => 'ro',
    lazy => 1,
    default => sub($self) {
            $self->has_meta_info
                ? $self->meta_info->{version}
                : $self->cpan_parse->distversion
    },
);

has dist_name => (
    is => 'ro',
    lazy => 1,
    default => sub($self) {
        $self->has_meta_info
            ? $self->meta_info->{distribution} || $self->meta_info->{name}
            : $self->cpan_parse->dist
            ;
    },
);

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Git::CPAN::Patch::Release

=head1 VERSION

version 2.5.0

=head1 AUTHOR

Yanick Champoux <yanick@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2022, 2021, 2018, 2017, 2016, 2015, 2014, 2013, 2012, 2011, 2010, 2009 by Yanick Champoux.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
