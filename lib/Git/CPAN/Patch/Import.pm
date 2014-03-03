package Git::CPAN::Patch::Import;
BEGIN {
  $Git::CPAN::Patch::Import::AUTHORITY = 'cpan:YANICK';
}
$Git::CPAN::Patch::Import::VERSION = '2.0.2';
use 5.10.0;

use strict;
use warnings;

{ 
    no warnings;
use 5.010;

use File::chmod ();  # must be before 'autodie' to hush the warnings

use autodie;

use Archive::Extract;
$Archive::Extract::PREFER_BIN = 1;

use File::Find;
use File::Basename;
use File::Spec::Functions;
use File::Temp qw(tempdir);
use File::Path;
use File::chdir;
use Path::Class qw/ file /;
use Cwd qw/ getcwd /;
use version;
use Git::Repository;
use CLASS;
use DateTime;

use CPANPLUS;
use BackPAN::Index;

}

our $BackPAN_URL = "http://backpan.perl.org/";
our $PERL_GIT_URL = 'git://perl5.git.perl.org/perl.git';

sub backpan_index {
    state $backpan = do {
        say "Loading BackPAN index (this may take a while)";
        BackPAN::Index->new;
    };
    return $backpan;
}

sub cpanplus {
    state $cpanplus = CPANPLUS::Backend->new;
    return $cpanplus;
}

# Make sure we can read tarballs and change directories
sub _fix_permissions {
    my $dir = shift;

    File::chmod::chmod "u+rx", $dir;
    find(sub {
        -d $_ ? File::chmod::chmod "u+rx", $_ : File::chmod::chmod "u+r", $_;
    }, $dir);
}

sub init_repo {
    my $module = shift;
    my $opts   = shift;

    my $dirname = ".";
    if ( defined $opts->{mkdir} ) {
        ( $dirname = $opts->{mkdir} || $module ) =~ s/::/-/g;

        if( -d $dirname ) {
            die "$dirname already exists\n" unless $opts->{update};
        }
        else {
            say "creating directory $dirname";

            # mkpath() does not play nice with overloaded objects
            mkpath "$dirname";
        }
    }

    {
        local $CWD = $dirname;

        if ( -d '.git' ) {
            if ( !$opts->{force} and !$opts->{update} ) {
                die "Aborting: git repository already present.\n",
                    "use '--force' if it's really what you want to do\n";
            }
        }
        else {
            Git::Repository->run('init');
        }
    }

    return File::Spec->rel2abs($dirname);
}


sub releases_in_git {
    my $repo = Git::Repository->new;
    return unless contains_git_revisions();
    my @releases = map  { m{\bgit-cpan-version:\s*(\S+)}x; $1 }
                   grep /^\s*git-cpan-version:/,
                     $repo->run(log => '--pretty=format:%b');
    return @releases;
}


sub rev_exists {
    my $rev = shift;
    my $repo = Git::Repository->new;

    return eval { $repo->run( 'rev-parse', $rev ); };
}


sub contains_git_revisions {
    return unless -d ".git";
    return rev_exists("HEAD");
}


sub import_one_backpan_release {
    my $release      = shift;
    my $opts         = shift;
    my $backpan_urls = $opts->{backpan} || $BackPAN_URL;

    # allow multiple backpan URLs to be supplied
    $backpan_urls = [ $backpan_urls ] unless (ref($backpan_urls) eq 'ARRAY');

    my $repo = Git::Repository->new;

    my( $last_commit, $last_version );

    # figure out if there is already an imported module
    if ( $last_commit = eval { $repo->run("rev-parse", "-q", "--verify", "cpan/master") } ) {
        $last_version = $repo->run("cpan-last-version");
    }

    my $tmp_dir = File::Temp->newdir(
        $opts->{tempdir} ? (DIR     => $opts->{tempdir}) : ()
    );

    my $archive_file = catfile($tmp_dir, $release->filename);
    mkpath dirname $archive_file;

    my $response;
    for my $backpan_url (@$backpan_urls) {
        my $release_url = $backpan_url . "/" . $release->prefix;

        say "Downloading $release_url";
        $response = get_from_url($release_url, $archive_file);
        last if $response->is_success;

        say "  failed @{[ $response->status_line ]}";
    }

    if( !$response->is_success ) {
        say "Fetch failed.  Skipping.";
        return;
    }

    if( !-e $archive_file ) {
        say "$archive_file is missing.  Skipping.";
        return;
    }

    say "extracting distribution";
    my $ae = Archive::Extract->new( archive => $archive_file );
    unless( $ae->extract( to => $tmp_dir ) ) {
        say "Couldn't extract $archive_file to $tmp_dir because ".$ae->error;
        say "Skipping";
        return;
    }

    my $dir = $ae->extract_path;
    if( !$dir ) {
        say "The archive is empty, skipping";
        return;
    }
    _fix_permissions($dir);

    my $tree = do {
        # don't overwrite the user's index
        local $ENV{GIT_INDEX_FILE} = catfile($tmp_dir, "temp_git_index");
        local $ENV{GIT_DIR} = catfile( getcwd(), '.git' );
        local $ENV{GIT_WORK_TREE} = $dir;

        local $CWD = $dir;

        my $write_tree_repo = Git::Repository->new( work_tree => $dir ) ;

        $write_tree_repo->run( qw(add -v --force .) );
        $write_tree_repo->run( "write-tree" );
    };

    # Create a commit for the imported tree object and write it into
    # refs/remotes/cpan/master
    local %ENV = %ENV;
    $ENV{GIT_AUTHOR_DATE}  ||= $release->date;

    my $author = $CLASS->cpanplus->author_tree($release->cpanid);
    $ENV{GIT_AUTHOR_NAME}  ||= $author->author;
    $ENV{GIT_AUTHOR_EMAIL} ||= $author->email;

    my @parents = grep { $_ } $last_commit;


    # commit message
    my $name    = $release->dist;
    my $version = $release->version || '';
    my $message = join ' ', ( $last_version ? "import" : "initial import of"), "$name $version from CPAN\n";
    $message .= <<"END";

git-cpan-module:   $name
git-cpan-version:  $version
git-cpan-authorid: @{[ $author->cpanid ]}
git-cpan-file:     @{[ $release->prefix ]}

END

    my $commit = $repo->run( { input => $message }, 'commit-tree', $tree,
           map { ( -p => $_ ) } @parents );

    # finally, update the fake branch and create a tag for convenience
    my $dist = $release->dist;
    print $repo->run('update-ref', '-m' => "import $dist", 'refs/heads/cpan/master', $commit );

    if( $version ) {
        my $tag = $version;
        $tag =~ s{^\.}{0.};  # git does not like a leading . as a tag name
        $tag =~ s{\.$}{};    # nor a trailing one
        if( $repo->run( "tag", "-l" => $tag ) ) {
            say "Tag $tag already exists, overwriting";
        }
        print $repo->run( "tag", "-f" => $tag, $commit );
        say "created tag '$tag' ($commit)";
    }
}


sub get_from_url {
    my($url, $file) = @_;

    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new;

    my $req = HTTP::Request->new( GET => $url );
    my $res = $ua->request($req, $file);

    return $res;
}


sub import_from_backpan {
    my ( $distname, $opts ) = @_;

    $distname =~ s/::/-/g;

    # handle --mkdir and raise an error if the target directory has already been git-initialized
    my $repo_dir = init_repo($distname, $opts);

    local $CWD = $repo_dir;

    my $backpan = $CLASS->backpan_index;
    my $dist = $backpan->dist($distname)
      or die "Error: no distributions found. ",
             "Are you sure you spelled the module name correctly?\n";

    fixup_repository();

    my %existing_releases;
    %existing_releases = map { $_ => 1 } releases_in_git() if $opts->{update};
    my $release_added = 0;
    for my $release ($dist->releases->search( undef, { order_by => "date" } )) {
        next if $existing_releases{$release->version};

        # skip .ppm files
        next if $release->filename =~ m{\.ppm\b};

        say "importing $release";
        import_one_backpan_release(
            $release,
            $opts,
        );
        $release_added++;
    }

    if( !$release_added ) {
        if( !keys %existing_releases ) {
            say "Empty repository for $dist.  Deleting.";

            # We can't delete it if we're inside it.
            $CWD = "..";
            rmtree $repo_dir;

            return;
        }
        else {
            say "No updates for $dist.";
            return;
        }
    }

    my $repo = Git::Repository->new;
    if( !rev_exists("master") ) {
        print $repo->run('checkout', '-t', '-b', 'master', 'cpan/master');
    }
    else {
        print $repo->run('checkout', 'master', '.'),
        $repo->run('merge', 'cpan/master');
    }

    return $repo_dir;
}


sub fixup_repository {
    my $repo = Git::Repository->new;

    return unless -d ".git";

    # We do our work in cpan/master, it might not exist if this
    # repo was cloned from gitpan.
    if( !rev_exists("cpan/master") and rev_exists("master") ) {
        print $repo->run('branch', '-t', 'cpan/master', 'master');
    }
}

use MetaCPAN::API;
my $mcpan = MetaCPAN::API->new;

sub find_release {
    my $input = shift;

    return eval { $mcpan->release( 
                        distribution => $mcpan->module($input)->{distribution}
                  ) }
        || eval { $mcpan->release( distribution => $input ) }
        || die "could not find release for '$input' on metacpan\n";

}

sub main {
    my $module = shift;
    my $opts   = shift;

    $DB::single = 1;
    

    if ( delete $opts->{backpan} ) {
        return import_from_backpan( $module, $opts );
    }

    my $repo = Git::Repository->new;

    my ( $last_commit, $last_version );

    # figure out if there is already an imported module
    if ( $last_commit = eval { $repo->run("rev-parse", "-q", "--verify", "cpan/master") } ) {
        $module     ||= $repo->run("cpan-which");
        $last_version = $repo->run("cpan-last-version");
    }

    die("Usage: git-cpan import Foo::Bar\n") unless $module;

    # first we figure out a module object from the module argument

    my $release = find_release($module);

    # based on the version number it figured out for us we decide whether or not to
    # actually import.

    my $name    = $release->{name};
    my $version = $release->{version};
    my $dist    = $release->{distribution};

     if ( $dist eq 'perl' ) {
        say "$name is a core modules, ",
            "clone perl from $PERL_GIT_URL instead.";
        exit;
    }

    my $prettyname = $dist . ( " ($module)" x ( $dist ne $module ) );

    if ( $last_version and $opts->{checkversion} ) {
        # if last_version is defined this is an update
        my $imported = version->new($last_version);
        my $will_import = version->new($release->{version});

        die "$name has already been imported\n" if $imported == $will_import;
    
        die "imported version $imported is more recent than $will_import, can't import\n"
          if $imported > $will_import;

        say "updating $prettyname from $imported to $will_import";
    
    } else {
        say "importing $prettyname";
    }

    require LWP::UserAgent;

    my $ua = LWP::UserAgent->new;

    # download the dist and extract into a temporary directory
    my $tmp_dir = tempdir( CLEANUP => 0 );

    say "downloading $dist";

    my $tarball = file( $tmp_dir, $release->{archive} );

    $ua->mirror( 
        $release->{download_url} => $tarball
    ) or die "couldn't fetch tarball\n";

    say "extracting distribution";

    my $archive = Archive::Extract->new( archive => $tarball );
    $archive->extract( to => $tmp_dir );

    my $dist_dir = $archive->extract_path 
        or die "extraction failed\n";

    # create a tree object for the CPAN module
    # this imports the source code without touching the user's working directory or
    # index

    my $tree = do {
        # don't overwrite the user's index
        local $ENV{GIT_INDEX_FILE} = catfile($tmp_dir, "temp_git_index");
        local $ENV{GIT_DIR} = catfile( getcwd(), '.git' );
        local $ENV{GIT_WORK_TREE} = $dist_dir;

        local $CWD = $dist_dir;

        my $write_tree_repo = Git::Repository->new( work_tree => $dist_dir );

        $write_tree_repo->run( qw(add -v --force .) );
        $write_tree_repo->run( "write-tree" );
    };

    # create a commit for the imported tree object and write it into
    # refs/heads/cpan/master

    {
        local %ENV = %ENV;

        my $author_obj = $mcpan->author($release->{author});

        # try to find a date for the version using the backpan index
        # secondly, if the CPANPLUS author object is a fake one (e.g. when importing a
        # URI), get the user object by using the ID from the backpan index
        unless ( $ENV{GIT_AUTHOR_DATE} ) {
            my $mtime = eval {
                DateTime->from_epoch( epoch => $release->{stat}{mtime})->ymd;
            };

            warn $@ if $@;

            # CPAN::Checksums makes YYYY-MM-DD dates, but GIT_AUTHOR_DATE
            # doesn't support that. 
            $mtime .= 'T00:00::00' 
                if $mtime =~ m/\A (\d\d\d\d) - (\d\d?) - (\d\d?) \z/x;

            if ( $mtime ) {
                $ENV{GIT_AUTHOR_DATE} = $mtime;
            } else {
                my %dists;

                if ( $opts->{backpan} ) {
                    # we need the backpan index for dates
                    my $backpan = $CLASS->backpan_index;

                    %dists = map { $_->filename => $_ }
                    $backpan->releases($release->{name});
                }

                if ( my $bp_dist = $dists{$dist} ) {

                    $ENV{GIT_AUTHOR_DATE} = $bp_dist->date;

                    if ( $author_obj->isa("CPANPLUS::Module::Author::Fake") ) {
                        $author_obj = $mcpan->author_tree($bp_dist->cpanid);
                    }
                } else {
                    say "Couldn't find upload date for $dist";

                    if ( $author_obj->isa("CPANPLUS::Module::Author::Fake") ) {
                        say "Couldn't find author for $dist";
                    }
                }
            }
        }

        # create the commit object
        $ENV{GIT_AUTHOR_NAME}  = $author_obj->{name} unless $ENV{GIT_AUTHOR_NAME};
        $ENV{GIT_AUTHOR_EMAIL} = $author_obj->{email}[0] unless $ENV{GIT_AUTHOR_EMAIL};

        my @parents = ( grep { $_ } $last_commit, @{ $opts->{parent} || [] } );

        my $message = join ' ', 
            ( $last_version ? "import" : "initial import of" ), 
            "$name $version from CPAN\n";
        $message .= <<"END";

git-cpan-module:   $name
git-cpan-version:  $version
git-cpan-authorid: @{[ $author_obj->{pauseid} ]}

END

        my $commit = $repo->run(
            { input => $message },
            'commit-tree', $tree, map { ( -p => $_ ) } @parents );

        # finally, update the fake remote branch and create a tag for convenience

        print $repo->run('update-ref', '-m' => "import $dist", 'refs/remotes/cpan/master', $commit );

        print $repo->run( tag => $version, $commit );

        say "created tag '$version' ($commit)";
    }

}

1;

=pod

=head1 NAME

Git::CPAN::Patch::Import

=head1 VERSION

version 2.0.2

=head1 DESCRIPTION

This is the guts of Git::CPAN::Patch::Import moved here to make it callable
as a function so git-backpan-init goes faster.

=head1 NAME

Git::CPAN::Patch::Import - The meat of git-cpan-import

=head1 AUTHOR

Yanick Champoux <yanick@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Yanick Champoux.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

__END__


1;
