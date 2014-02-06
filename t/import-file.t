use strict;
use warnings;

use Test::More tests => 7;

use Git::CPAN::Patch::Command::Import;
use File::Temp qw/ tempdir /;
use Git::Repository 'AUTOLOAD';

my $root = tempdir( 'repo_XXXX', CLEANUP => 1, DIR => './t' );

Git::Repository->run( init => $root );
my $git = Git::Repository->new( work_tree => $root );

note "git directory: $root";

my $command = Git::CPAN::Patch::Command::Import->new(
    root => $root,
    thing_to_import => './t/corpus/Git-CPAN-Patch-0.4.5.tar.gz',
);

$command->run;

is_deeply [ $git->branch( '-a' ) ] => [ '  remotes/cpan/master' ], 
    "branch is there";

is_deeply [ $git->tag ] => [ 'v0.4.4' ], "tag is there";

my $log = join "\n", $git->log( 'cpan/master' );

like $log => qr/Author: Yanick Champoux <yanick\@cpan.org>/, 'author';

like $log => qr/initial import of Git-CPAN-Patch 0\.4\.4/, "main message";

like $log => qr/git-cpan-module:\s*Git-CPAN-Patch/, 'git-cpan-module';
like $log => qr/git-cpan-version:\s*0.4.4/, 'git-cpan-version';
like $log => qr/git-cpan-authorid:\s*YANICK/, 'git-cpan-authorid';






