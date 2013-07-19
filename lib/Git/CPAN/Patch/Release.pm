package Git::CPAN::Patch::Release;
BEGIN {
  $Git::CPAN::Patch::Release::AUTHORITY = 'cpan:YANICK';
}
{
  $Git::CPAN::Patch::Release::VERSION = '1.3.0';
}

use strict;
use warnings;

use Method::Signatures::Simple;
use File::chdir;
use File::Temp qw/ tempdir /;
use version;

use Moose;

with 'MooseX::Role::Tempdir' => {
    tmpdir_opts => { CLEANUP => 1 },
};


has tarball => (
    is => 'ro',
    isa => 'Str',
    required => 1,
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
        version->parse(
            $self->meta_info 
                ? $self->meta_info->{version} 
                : $self->cpan_parse->distversion
        );
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
