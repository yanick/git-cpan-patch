package Git::CPAN::Patch::Command::FormatPatch;
#ABSTRACT: Format patches using C<cpan/master> as the origin reference

use 5.20.0;

use strict;
use warnings;


use MooseX::App::Command;

with 'Git::CPAN::Patch::Role::Git';
with 'Git::CPAN::Patch::Role::Patch';

use experimental qw/
    signatures
    postderef
/;


sub run ($self) { $self->format_patch }

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

    % git-cpan format-patch

=head1 DESCRIPTION

This is just like running C<git format-patch cpan/master>.

=head1 AUTHORS

Yuval Kogman C<< <nothingmuch@woobling.org> >>

Yanick Champoux C<< <yanick@cpan.org> >>

=head1 SEE ALSO

L<Git::CPAN::Patch>

L<git-format-patch>

=cut


