package Git::CPAN::Patch::Command::SendPatch;
our $AUTHORITY = 'cpan:YANICK';
#ABSTRACT: create patch files and submit them to RT
$Git::CPAN::Patch::Command::SendPatch::VERSION = '2.4.0';
use 5.10.0;

use strict;
use warnings;

use MooseX::App::Command;

with 'Git::CPAN::Patch::Role::Git';
with 'Git::CPAN::Patch::Role::Patch';

use experimental qw/
    signatures
    postderef
/;

sub run ($self) {
    $self->format_patch;

    if ( $self->nbr_patches > 1 ) {
        say "Refusing to send more than one patch (each patch email will be in its own RT ticket).";
        say "Run git-cpan-send-email manually to override, or squash your commits.";

        say and unlink($_) for $self->all_patches;

        return;
    }

    $self->send_emails( $self->all_patches );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Git::CPAN::Patch::Command::SendPatch - create patch files and submit them to RT

=head1 VERSION

version 2.4.0

=head1 SYNOPSIS

    % git-cpan send-patch

=head1 DESCRIPTION

This command runs C<git-cpan format-patch> and then if there is one patch file
runs C<git-cpan send-email>.

Multiple patches are not sent because C<git send-email> creates a separate
message for each patch file, resulting in multiple tickets.

=head1 AUTHOR

Yanick Champoux <yanick@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2021, 2018, 2017, 2016, 2015, 2014, 2013, 2012, 2011, 2010, 2009 by Yanick Champoux.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
