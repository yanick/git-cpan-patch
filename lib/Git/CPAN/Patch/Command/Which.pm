package Git::CPAN::Patch::Command::Which;
BEGIN {
  $Git::CPAN::Patch::Command::Which::AUTHORITY = 'cpan:YANICK';
}
{
  $Git::CPAN::Patch::Command::Which::VERSION = '1.0.0';
}
#ABSTRACT: reports the repository's module

use 5.10.0;

use strict;
use warnings;

use Method::Signatures;
use MooseX::App::Command;

with 'Git::CPAN::Patch::Role::Git'; 
with 'Git::CPAN::Patch::Role::Patch';

method run {
    say $self->module_name; 
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 SYNOPSIS

    % git-cpan which

=head1 DESCRIPTION

This command prints the name of the module tracked in C<cpan/master>.

=head1 AUTHORS

Yanick Champoux C<< <yanick@cpan.org> >>

Yuval Kogman C<< <nothingmuch@woobling.org> >>

=head1 SEE ALSO

L<Git::CPAN::Patch>

=cut
