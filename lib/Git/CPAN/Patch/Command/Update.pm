package Git::CPAN::Patch::Command::Update;
BEGIN {
  $Git::CPAN::Patch::Command::Update::AUTHORITY = 'cpan:YANICK';
}
#ABSTRACT: Import the latest version of a module and rebase the current branch
$Git::CPAN::Patch::Command::Update::VERSION = '2.0.3';
use 5.10.0;

use strict;
use warnings;

use Method::Signatures::Simple;
use Git::Repository;

use MooseX::App::Command;

extends 'Git::CPAN::Patch::Command::Import';


#TODO check for versions before download

has last_import_before_run => (
    is => 'rw',
);

before run => method {
    eval { $self->set_last_import_before_run($self->last_commit) }
        or die "branch 'cpan/master' doesn't exist yet (import first)\n";
    $self->set_thing_to_import( $self->tracked_distribution );
};

after run => method {
    return if $self->last_import_before_run eq $self->last_commit;

    $self->git_run( rebase => 'cpan/master' );
};


__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Git::CPAN::Patch::Command::Update - Import the latest version of a module and rebase the current branch

=head1 VERSION

version 2.0.3

=head1 SYNOPSIS

    % git-cpan update

=head1 DESCRIPTION

This command runs C<git-cpan import>, and then if C<cpan/master> was updated
runs C<git rebase cpan/master>, bringing your patches up to date with the
upstream.

=head1 AUTHORS

Yuval Kogman C<< <nothingmuch@woobling.org> >>

Yanick Champoux C<< <yanick@cpan.org> >>

=head1 SEE ALSO

L<Git::CPAN::Patch>, L<git-cpan-import>

=head1 AUTHOR

Yanick Champoux <yanick@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Yanick Champoux.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
