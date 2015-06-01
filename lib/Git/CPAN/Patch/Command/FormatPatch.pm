package Git::CPAN::Patch::Command::FormatPatch;
our $AUTHORITY = 'cpan:YANICK';
#ABSTRACT: Format patches using C<cpan/master> as the origin reference
$Git::CPAN::Patch::Command::FormatPatch::VERSION = '2.1.0';
use 5.10.0;

use strict;
use warnings;

use Method::Signatures::Simple;

use MooseX::App::Command;

with 'Git::CPAN::Patch::Role::Git';
with 'Git::CPAN::Patch::Role::Patch';


method run {
    $self->format_patch;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Git::CPAN::Patch::Command::FormatPatch - Format patches using C<cpan/master> as the origin reference

=head1 VERSION

version 2.1.0

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

=head1 AUTHOR

Yanick Champoux <yanick@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Yanick Champoux.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
