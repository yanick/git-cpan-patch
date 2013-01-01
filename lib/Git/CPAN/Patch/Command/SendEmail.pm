package Git::CPAN::Patch::Command::SendEmail;
BEGIN {
  $Git::CPAN::Patch::Command::SendEmail::AUTHORITY = 'cpan:YANICK';
}
{
  $Git::CPAN::Patch::Command::SendEmail::VERSION = '1.0.0';
}
#ABSTRACT: use C<git-send-email> to submit patches to CPAN RT

use 5.10.0;

use strict;
use warnings;

use Method::Signatures;

use MooseX::App::Command;

with 'Git::CPAN::Patch::Role::Git';
with 'Git::CPAN::Patch::Role::Patch';

method run {
    $self->send_emails($self->extra_argv);
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



