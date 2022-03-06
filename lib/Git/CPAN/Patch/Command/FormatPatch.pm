package Git::CPAN::Patch::Command::FormatPatch;
our $AUTHORITY = 'cpan:YANICK';
#ABSTRACT: Format patches using C<cpan/master> as the origin reference
$Git::CPAN::Patch::Command::FormatPatch::VERSION = '2.5.0';
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

=pod

=encoding UTF-8

=head1 NAME

Git::CPAN::Patch::Command::FormatPatch - Format patches using C<cpan/master> as the origin reference

=head1 VERSION

version 2.5.0

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

This software is copyright (c) 2022, 2021, 2018, 2017, 2016, 2015, 2014, 2013, 2012, 2011, 2010, 2009 by Yanick Champoux.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
