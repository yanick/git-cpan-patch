use strict;
use warnings;

use Test::More tests => 2;

use Git::CPAN::Patch::Command::Clone;
use Path::Tiny;
use Git::Repository;
use Carp;

my $data = {
                    name => 'Git-CPAN-Patch',
                    author => 'YANICK',
                    date => '2011-03-06T01:02:03',
                    download_url => './t/corpus/Git-CPAN-Patch-0.4.5.tar.gz',
                    version => '0.4.4',
                }; 


package FakeMetaCPAN {
    sub module { !!0 }
    sub release {
        if ($_[1] eq 'Git-CPAN-Patch') {
            return bless { data => $data }, 'FakeMetaCPAN::Release';
        }
        elsif (ref $_[1]) {
            return bless { items => [
                bless {
                    data => {
                        status => 'cpan',
                        %$data,
                        metadata => {
                            author => [
                                'Yanick Champoux <yanick@cpan.org>'
                            ],
                        },
                    },
                }, 'FakeMetaCPAN::Release'
            ] };
        }
        else {
            local $Carp::RefArgFormatter = sub {
                $Data::Dumper::Indent = 1;
                $Data::Dumper::Terse = 1;
                Data::Dumper::Dumper($_[0]);
            };
            Carp::confess "Unexpected test input!";
        }
    }
}
package FakeMetaCPAN::ResultSet {
    sub next { shift @{ $_[0]->{items} } }
}
package FakeMetaCPAN::Release {
    sub data { $_[0]->{data} }
    sub meta { $_[0]->{data}{metadata} }
}

my $metacpan = bless {}, 'FakeMetaCPAN';

subtest $_ => sub { test_clone($_) } for
    qw[ Git-CPAN-Patch ./t/corpus/Git-CPAN-Patch-0.4.5.tar.gz ];

sub test_clone {
    my $thing = shift;

    plan tests => 7;

    my $root = Path::Tiny->tempdir( 'repo_XXXX', CLEANUP => 1, DIR => './t' );

    Git::Repository->run( init => $root );
    my $git = Git::Repository->new( work_tree => $root );

    note "git directory: $root";

    my $command = Git::CPAN::Patch::Command::Import->new(
        root => $root,
        thing_to_import => $thing,
        metacpan => $metacpan,
    );

    $command->run;

    like $git->run('branch', '-a', '--no-color') => qr#remotes/cpan/master#,
        "branch is there";

    like $git->run('tag') => qr[v0.4.], "tag is there";

    my $log = join "\n", $git->run('log', 'cpan/master' );

    like $log => qr/Author:\s+Yanick\s+Champoux\s+<yanick\@cpan.org>/, 'author';

    like $log => qr/initial import of Git-CPAN-Patch 0\.4\./, "main message";

    like $log => qr/git-cpan-module:\s*Git-CPAN-Patch/, 'git-cpan-module';
    like $log => qr/git-cpan-version:\s*0.4./, 'git-cpan-version';
    like $log => qr/git-cpan-authorid:\s*YANICK/, 'git-cpan-authorid';
}
