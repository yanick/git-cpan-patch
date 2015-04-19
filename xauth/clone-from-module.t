use strict;
use warnings;

use Test::More tests => 1;

use Git::CPAN::Patch::Command::Clone;
use Path::Tiny;
use Git::Repository;

my %things_to_import = (
    'Git::CPAN::Patch' => { author_name => 'Yanick Champoux', cpan_id => 'YANICK', },
#    'CSS-LESSp' => { author_name => 'Ivan Drinchev', cpan_id => 'DRINCHEV', },
#    './t/corpus/Git-CPAN-Patch-0.4.5.tar.gz' => { author_name => 'Yanick Champoux', cpan_id => 'YANICK', },
#    './/t/corpus/Git-CPAN-Patch-0.4.5.tar.gz' => { author_name => 'Yanick Champoux', cpan_id => 'YANICK', },
);

my $here = path('.')->absolute;
use File::chdir;

while( my( $thing, $config ) = each %things_to_import ) {
    subtest $thing => sub {
        local $CWD = $here;

        my %config = %$config;

        my $tmpdir = Path::Tiny->tempdir( $here.'/tmp/XXXXXXXX', CLEANUP => 0, TMPDIR => 0 );
        diag "temp dir: $tmpdir";

        Git::CPAN::Patch::Command::Clone->new(
            norepository    => 1,
            latest          => 1,
            target          => $tmpdir->stringify,
            thing_to_import => $thing,
        )->run;

        my $repo = Git::Repository->new( work_tree => $tmpdir->stringify );

        my $log = $repo->run( qw/ log -1 / );

        unlike $log => qr/Author:\s+unknown/;
        like $log => qr/Author:\s+$config{author_name}/;
        unlike $log => qr/git-cpan-authorid:\s+unknown/;
        like $log => qr/git-cpan-authorid:\s+$config{cpan_id}/;
    };
}




