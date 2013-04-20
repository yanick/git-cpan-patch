package Git::CPAN::Patch::Command::SendEmail;
#ABSTRACT: use C<git-send-email> to submit patches to CPAN RT

use 5.10.0;

use strict;
use warnings;

use Method::Signatures::Simple;

use MooseX::App::Command;

with 'Git::CPAN::Patch::Role::Git';
with 'Git::CPAN::Patch::Role::Patch';

parameter extra_arg => (
    is => 'rw',
    isa => 'Str',
    required => 0,
);

method run {
    $self->send_emails($self->extra_arg);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 SYNOPSIS

    % git-cpan send_email

=head1 DESCRIPTION

This command provides a C<--to> parameter to C<git send-email> that corresponds
to the RT queue of the imported module.



