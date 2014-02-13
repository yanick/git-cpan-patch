package Git::CPAN::Patch::Command::Import;
#ABSTRACT: Import a module into a git repository

use 5.10.0;

use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Method::Signatures::Simple;
use Git::Repository;
use Git::CPAN::Patch::Import;
use File::chdir;
use Git::CPAN::Patch::Release;
use Path::Class qw/ dir /;

use MooseX::App::Command;

extends 'Git::CPAN::Patch';
with 'Git::CPAN::Patch::Role::Git';

with 'MooseX::Role::Tempdir' => {
    tmpdir_opts => { CLEANUP => 1 },
};

use experimental qw(smartmatch);

our $PERL_GIT_URL = 'git://perl5.git.perl.org/perl.git';
our $BackPAN_URL = "http://backpan.perl.org/";

option 'norepository' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
    documentation => "don't clone git repository",
);

option 'latest' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
    documentation => 'only pick latest release, if clone from CPAN',
);

option check => (
    is => 'ro',
    isa => 'Bool',
    default => 1,
    documentation => q{Verifies that the imported version is greater than what is already imported},
);

option parent  => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub { [] },
    documentation => q{Parent of the imported release (can have more than one)},
);

parameter thing_to_import => (
    is  => 'rw',
    isa => 'Str',
    required => 0,
);

has metacpan => (
    is => 'ro',
    default => sub {
        require MetaCPAN::API;
        return MetaCPAN::API->new;
    },
);


method get_releases_from_url($url) {
    require LWP::Simple;

    ( my $name = $url ) =~ s#^.*/##;
    my $destination = $self->tmpdir . '/'.$name;

    say "copying '$url' to '$destination'";

    LWP::Simple::mirror( $url => $destination ) or die;

    return Git::CPAN::Patch::Release->new( tarball => $destination );
}

method get_releases_from_local_file($path) {
    return Git::CPAN::Patch::Release->new( tarball => $path );
}

method clone_git_repo($release,$url) {
    $self->git_run( 'remote', 'add', 'cpan', $url );
    $self->git_run( 'fetch', 'cpan' );
}

method get_releases_from_cpan($dist_or_module) {
    require MetaCPAN::API;

    # is it a module belonging to a distribution?
    my $dist = eval{ $self->metacpan->module($dist_or_module)->{distribution} 
    } || $dist_or_module;

     if ( $dist eq 'perl' ) {
        die "$dist_or_module is a core modules, ",
            "clone perl from $PERL_GIT_URL instead.\n";
    }

    if( my $latest_release = !$self->norepository && $self->metacpan->release( distribution => $dist)) {
        my $repo = $latest_release->{metadata}{resources}{repository};
        if( $repo and $repo->{type} eq 'git' ) {
            say "Git repository found: ", $repo->{url};
            $self->clone_git_repo(Git::CPAN::Patch::Release->new( dist_name =>
                    $dist),$repo->{url});
            return;
        }
    }

    if ( $self->latest ) {
        my $rel = $self->metacpan->release( distribution => $dist);
        return Git::CPAN::Patch::Release->new(
            map { $_ => $rel->{$_} } qw/ name author date download_url version /
        );
    }

    my $releases = eval { $self->metacpan->release( search => {
        q => "distribution:$dist",
        fields => 'name,author,date,download_url,version',
        ( filter => 'status:latest' ) x $self->latest
    }) }
    or die "could not find release for '$dist_or_module' on metacpan\n";

    my @releases = @{ $releases->{hits}{hits} };

    $_->{author_cpan} = delete $_->{author} for @releases;

    return sort { $a->date cmp $b->date } 
           map { Git::CPAN::Patch::Release->new( %{$_->{fields}} ) }  
                @releases;
               
}

method get_releases_from_backpan($dist_name) {
    say "Loading BackPAN index (this may take a while)";
    require BackPAN::Index;
    my $backpan = BackPAN::Index->new;

    my $dist =$backpan->dist($dist_name)
        or die "couldn't find distribution '$dist_name' on BackPAN";

    return
        map {
            my $archive_file = $self->tmpdir . '/' . $_->filename;
            my $release_url = $BackPAN_URL . "/" . $_->prefix;
            say "fetching $release_url";
            my $okay = not LWP::Simple::is_error(
                LWP::Simple::mirror( $release_url =>
                $archive_file ) );

            warn unless $okay;

            $okay ? Git::CPAN::Patch::Release->new( tarball => $archive_file ) : ();
        }
        grep { $_->filename !~ m{\.ppm\b} }
        $dist->releases->search( undef, { order_by => "date" } )->all;

}

method releases_to_import {
    given ( $self->thing_to_import ) {
        when ( qr/^(?:https?|file|ftp)::/ ) {
            return $self->get_releases_from_url( $_ );
        }
        when ( -f $_ ) {
            return $self->get_releases_from_local_file( $_ );
        }
        default {
            return $self->get_releases_from_cpan($_);
        }
    }
}

method import_release($release) {
    my $import_version = $release->dist_version;

    if ( $self->check and $self->last_imported_version ) {
        return say $release->dist_name . " $import_version has already been imported\n"
            if $import_version == $self->last_imported_version;

        return say sprintf "last imported version %s is more recent than %s"
            . ", can't import",
            $self->last_imported_version, $import_version
          if $import_version <= $self->last_imported_version;
    }

    # create a tree object for the CPAN module
    # this imports the source code without touching the user's working directory or
    # index

    my $tree = do {
        # don't overwrite the user's index
        local $ENV{GIT_INDEX_FILE} = $self->tmpdir . "/temp_git_index";
        local $ENV{GIT_DIR} = dir($self->root . '/.git')->absolute->stringify;
        local $ENV{GIT_WORK_TREE} = $release->extracted_dir;

        local $CWD = $release->extracted_dir;

        my $write_tree_repo = Git::Repository->new( work_tree => $CWD );

        $write_tree_repo->run( qw(add -v --all --force .) );
        $write_tree_repo->run( "write-tree" );
    };

    # create a commit for the imported tree object and write it into
    # refs/heads/cpan/master
    {
        local %ENV = %ENV;

        # TODO authors and author_date

        # create the commit object
        $ENV{GIT_AUTHOR_NAME}  ||= $release->author_name;
        $ENV{GIT_AUTHOR_EMAIL} ||= $release->author_email;
        $ENV{GIT_AUTHOR_DATE} ||= $release->date;

        my @parents = grep { $_ } $self->last_commit, @{ $self->parent };

        my $message = sprintf "%s %s %s\n",
            ( $self->first_import ? 'initial import of' : 'import' ),
            $release->dist_name, $release->dist_version;

        no warnings 'uninitialized';
        $message .= <<"END";

git-cpan-module:   @{[ $release->dist_name ]}
git-cpan-version:  @{[ $release->dist_version ]}
git-cpan-authorid: @{[ $release->author_cpan ]}

END

        my $commit = $self->git_run(
            { input => $message },
            'commit-tree', $tree, map { ( -p => $_ ) } @parents );

        # finally, update the fake remote branch and create a tag for convenience

        print $self->git_run('update-ref', '-m' => "import " . $release->dist_name, 'refs/remotes/cpan/master', $commit );

        print $self->git_run( tag => 'v'.$release->dist_version, $commit );

        say "created tag '@{[ 'v'.$release->dist_version ]}' ($commit)";
    }

}

method run {
    my @releases = $self->releases_to_import;

    $self->import_release($_) for @releases;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod


=head1 SYNOPSIS

    # takes any string CPANPLUS handles:

    % git-cpan import Foo::Bar
    % git-cpan import A/AU/AUTHORID/Foo-Bar-0.03.tar.gz
    % git-cpan import http://backpan.cpan.org/authors/id/A/AU/AUTHORID/Foo-Bar-0.03.tar.gz

    # If the repository is already initialized, can be run with no arguments to
    # import the latest version
    git-cpan import


=head1 DESCRIPTION

This command is used internally by C<git-cpan-init>, C<git-cpan-update> and
C<git-backpan-init>.

This command takes a tarball, extracts it, and imports it into the repository.

It is only possible to update to a newer version of a module.

The module history is tracked in C<refs/remotes/cpan/master>.

Tags are created for each version of the module.

This command does not touch the working directory, and is safe to run even if
you have pending work.

=head1 OPTIONS

=over

=item  --backpan

Enables Backpan index fetching (to get the author and release date).


=item --check, --nocheck

Explicitly enables/disables version checking.  If version checking is
enabled, which is the default, git-cpan-import will refuse to import a
version of the package
that has a smaller version number than the HEAD of the branch I<cpan/master>.

=item --parent

Allows adding extra parents when
importing, so that when a patch has been incorporated into an upstream
version the generated commit is like a merge commit, incorporating both
the CPAN history and the user's local history.

For example, this will set the current HEAD of the master branch as a parent of
the imported CPAN package:

    $ git checkout master
    $ git-cpan import --parent HEAD My-Module

More than one '--parent' can be specified.

=back

=head1 AUTHORS

Yuval Kogman C<< <nothingmuch@woobling.org> >>

Yanick Champoux C<< <yanick@cpan.org> >>


=head1 SEE ALSO

L<Git::CPAN::Patch>

=cut
