use strict;
use warnings;

use Test2::V1 -Pip;

use Git::CPAN::Patch::Command::Clone;
use File::Temp qw/ tempdir /;
use Git::Repository 'AUTOLOAD';

my $data = {
                    name => 'Git-CPAN-Patch',
                    author => 'YANICK',
                    date => '2011-03-06T01:02:03',
                    download_url => './t/corpus/Git-CPAN-Patch-0.4.5.tar.gz',
                    version => '0.4.4',
                }; 

my $metacpan = mock {} => (
    add => [
        module => sub { 0 },
        release => sub {
            return mock { data => $data }
                if $_[1] eq 'Git-CPAN-Patch';

            if (ref $_[1]) {
                my @releases = (
                    mock {
                        data => {
                            'status' => 'cpan',
                            'distribution' => 'Git-CPAN-Patch',
                            author => 'YANICK',
                            date => '2011-03-06T01:02:03',
                            download_url => './t/corpus/Git-CPAN-Patch-0.4.5.tar.gz',
                            version => '0.4.4',
                            metadata => {
                                'author' => [
                                    'Yanick Champoux <yanick@cpan.org>'
                                ],
                            },
                        },
                        meta => {
                            'author' => [
                                'Yanick Champoux <yanick@cpan.org>'
                            ],
                        },
                    },
                );
                return mock {} => (
                    add => [
                        next => sub {
                            return shift @releases;
                        },
                    ],
                );
            }

            require Carp;
            Carp::confess "Unhandled release: $_[1]";
        },
    ],
);

subtest $_ => sub { test_clone($_) } for
    qw[ Git-CPAN-Patch ./t/corpus/Git-CPAN-Patch-0.4.5.tar.gz ];

sub test_clone {
    my $thing = shift;

    plan tests => 7;

    my $root = tempdir( 'repo_XXXX', CLEANUP => 1, DIR => './t' );

    Git::Repository->run( init => $root );
    my $git = Git::Repository->new( work_tree => $root );

    note "git directory: $root";

    my $command = Git::CPAN::Patch::Command::Import->new(
        root => $root,
        thing_to_import => $thing,
        metacpan => $metacpan,
    );

    $command->run;

    like $git->branch( '-a', '--no-color' ) => qr#remotes/cpan/master#,
        "branch is there";

    like $git->tag => qr[v0.4.], "tag is there";

    my $log = join "\n", $git->log( 'cpan/master' );

    like $log => qr/Author:\s+Yanick\s+Champoux\s+<yanick\@cpan.org>/, 'author';

    like $log => qr/initial import of Git-CPAN-Patch 0\.4\./, "main message";

    like $log => qr/git-cpan-module:\s*Git-CPAN-Patch/, 'git-cpan-module';
    like $log => qr/git-cpan-version:\s*0.4./, 'git-cpan-version';
    like $log => qr/git-cpan-authorid:\s*YANICK/, 'git-cpan-authorid';
}

done_testing;
