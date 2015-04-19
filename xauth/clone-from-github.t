use strict;
use warnings;

use Test::More tests => 1;

use Git::CPAN::Patch::Command::Clone;
use Path::Tiny;
use Git::Repository;

my $tmpdir = Path::Tiny->tempdir( path('.')->absolute.'/tmp/XXXXXXXX', CLEANUP => 0, TMPDIR => 0 );
diag "temp dir: $tmpdir";

Git::CPAN::Patch::Command::Clone->new(
    target          => $tmpdir->stringify,
    thing_to_import => 'Git::CPAN::Patch',
)->run;

my $repo = Git::Repository->new( work_tree => $tmpdir->stringify );

my $log = $repo->run( qw/ log -1 / );

my %config = ( author_name => 'Yanick Champoux', cpan_id => 'YANICK', );

unlike $log => qr/Author:\s+unknown/;
like $log => qr/Author:\s+$config{author_name}/;
unlike $log => qr/git-cpan-authorid:\s+unknown/;
like $log => qr/git-cpan-authorid:\s+$config{cpan_id}/;
