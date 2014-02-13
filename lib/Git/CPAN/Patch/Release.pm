package Git::CPAN::Patch::Release;
BEGIN {
  $Git::CPAN::Patch::Release::AUTHORITY = 'cpan:YANICK';
}
$Git::CPAN::Patch::Release::VERSION = '2.0.0';
use strict;
use warnings;

use Method::Signatures::Simple;
use File::chdir;
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
        
        if ( $self->has_meta_info ) {
            return $1 if $self->meta_info->{author}[0] =~ /^\s*(.*?)\s*</;
        }
        return undef;
    },
);

has author_cpan => (
    is => 'ro',
    isa => 'Maybe[Str]',
    lazy => 1,
    default => sub {
        my $self = shift;
        
        return uc $1 if $self->author_email =~ /(.*)\@cpan\.org$/;

        return undef;
    },
);

has author_email => (
    is => 'ro',
    isa => 'Maybe[Str]',
    predicate => 'has_author_email',
    lazy => 1,
    default => sub {
        my $self = shift;
        
        if ( $self->has_meta_info ) {
            return $1 if $self->meta_info->{author}[0] =~ /<(.*?)>\s*$/;
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
    predicate => 'has_download_url',
);

has date => (
    is => 'ro',
    isa => 'Str',
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
        if ( $self->has_download_url ) {
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

        my $archive = Archive::Extract->new( archive => $self->tarball );
        $archive->extract( to => $self->tmpdir );

        return $archive->extract_path || die "extraction failed\n";
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
    predicate => 'has_meta_info',
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
            ? $self->meta_info->{name}
            : $self->cpan_parse->dist
            ;
    },
);

1;
