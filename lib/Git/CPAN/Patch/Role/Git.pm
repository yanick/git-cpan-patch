package Git::CPAN::Patch::Role::Git;
BEGIN {
  $Git::CPAN::Patch::Role::Git::AUTHORITY = 'cpan:YANICK';
}
{
  $Git::CPAN::Patch::Role::Git::VERSION = '1.3.0';
}
#ABSTRACT: provides access to Git repository

use strict;
use warnings;

use Method::Signatures::Simple;
use version;

use Moose::Role;
use MooseX::App::Role;
use MooseX::SemiAffordanceAccessor;

use Git::Repository;

option root => (
    is => 'rw',
    isa => 'Str',
    default => '.' ,
    documentation => 'Location of the Git repository',
);

has git => (
    is => 'ro',
    isa => 'Git::Repository',
    lazy => 1,
    default => method {
        Git::Repository->new(
            work_tree => $self->root
        );
    },
    handles => {
        git_run => 'run',
    },
);

method last_commit {
    eval { $self->git_run('rev-parse', '--verify', 'cpan/master') }
}

method last_imported_version {
    my $last_commit = $self->last_commit or return version->parse(0);

    my $last = join "\n", $self->git_run( log => '--pretty=format:%b', '-n', 1, $last_commit );

    $last =~ /git-cpan-module:\ (.*?) \s+ git-cpan-version: \s+ (\S+)/sx
        or die "Couldn't parse message:\n$last\n";

    return version->parse($2);
}

method tracked_distribution {
    my $last_commit = $self->last_commit or return;

    my $last = join "\n", $self->git_run( log => '--pretty=format:%b', '-n', 1, $last_commit );

    $last =~ /git-cpan-module:\s+ (.*?) \s+ git-cpan-version: \s+ (\S+)/sx
        or die "Couldn't parse message:\n$last\n";

    return $1;
}

method first_import {
    return !$self->last_commit;
}

1;
