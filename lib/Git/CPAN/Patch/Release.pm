package Git::CPAN::Patch::Release;

use strict;
use warnings;

use Method::Signatures::Simple;
use File::chdir;
use Archive::Any;
use File::Temp qw/ tempdir tempfile /;
use version;

use Moose;

with 'MooseX::Role::Tempdir' => {
    tmpdir_opts => { CLEANUP => 1 },
};

has author_name => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;

        if ( $self->meta_info ) {
            my $author = $self->meta_info->{author};
            $author = $author->[0] if ref $author;
            return $1 if $author =~ /^\s*(.*?)\s*</;
        }
        return 'unknown';
    },
);

has author_cpan => (
    is => 'ro',
    isa => 'Maybe[Str]',
    lazy => 1,
    default => sub {
        my $self = shift;
        
        no warnings 'uninitialized';
        return uc $1 if $self->author_email =~ /(.*)\@cpan\.org$/;

        return 'unknown@cpan.org';
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
            my $author = $self->meta_info->{author};
            $author = $author->[0] if ref $author;
            return $1 if $author =~ /<(.*?)>\s*$/;
        }
        return undef;
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
                    or die "could not retrieve ", $self->download_url;
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
    default => method {

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
    default => method {
        require CPAN::ParseDistribution;
        CPAN::ParseDistribution->new( $self->tarball );
    },
);

has meta_info => (
    is => 'ro',
    lazy => 1,
    default => method {
        require CPAN::Meta;
        
        local $CWD = $self->extracted_dir;
        return eval { CPAN::Meta->load_file('META.json') } 
            || eval { CPAN::Meta->load_file('META.yml')  }; 
    },
);

has dist_version => (
    is => 'ro',
    lazy => 1,
    default => method {
            $self->meta_info 
                ? $self->meta_info->{version} 
                : $self->cpan_parse->distversion
    },
);

has dist_name => (
    is => 'ro',
    lazy => 1,
    default => method {
        $self->meta_info 
            ? $self->meta_info->{distribution} || $self->meta_info->{name}
            : $self->cpan_parse->dist
            ;
    },
);

1;
