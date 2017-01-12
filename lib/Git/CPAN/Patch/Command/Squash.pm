package Git::CPAN::Patch::Command::Squash;
our $AUTHORITY = 'cpan:YANICK';
#ABSTRACT: Combine multiple commits into one patch
$Git::CPAN::Patch::Command::Squash::VERSION = '2.3.1';
use 5.10.0;

use strict;
use warnings;

use Method::Signatures::Simple;
use Git::Repository;

use MooseX::App::Command;

with 'Git::CPAN::Patch::Role::Git';

has first_arg => (
    is => 'ro',
    isa => 'Str',
    required => 0,
);

has branch => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => method {
        $self->first_arg || 'patch';
    },
);

method run {
    my $head = $self->git_run("rev-parse", "--verify", "HEAD");

    say for $self->git_run("checkout", "-b", $self->branch, "cpan/master");

    say for $self->git_run("merge", "--squash", $head);

    say "";

    say "Changes squashed onto working directory, commit and run git-cpan send_patch";
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Git::CPAN::Patch::Command::Squash - Combine multiple commits into one patch

=head1 VERSION

version 2.3.1

=head1 SYNOPSIS

    % git-cpan squash temp_submit_branch

    % git commit -m "This is my message"

    % git-cpan send-patch --compose

    # delete the branch now that we're done
    % git checkout master
    % git branch -D temp_submit_branch

=head1 DESCRIPTION

This command creates a new branch from C<cpan/master> runs
C<git merge --squash> against your head revision. This stages all the files for
the branch and allows you to create a combined commit in order to send a single
patch easily.

=head1 AUTHOR

Yanick Champoux <yanick@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2017 by Yanick Champoux.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
