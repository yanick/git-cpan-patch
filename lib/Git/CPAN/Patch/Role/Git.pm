package Git::CPAN::Patch::Role::Git;
BEGIN {
  $Git::CPAN::Patch::Role::Git::AUTHORITY = 'cpan:YANICK';
}
#ABSTRACT: provides access to Git repository
$Git::CPAN::Patch::Role::Git::VERSION = '2.0.4';
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

__END__

=pod

=encoding UTF-8

=head1 NAME

Git::CPAN::Patch::Role::Git - provides access to Git repository

=head1 VERSION

version 2.0.4

=head1 AUTHOR

Yanick Champoux <yanick@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Yanick Champoux.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
