package Git::CPAN::Patch::Command::SendEmail;
our $AUTHORITY = 'cpan:YANICK';
#ABSTRACT: use C<git-send-email> to submit patches to CPAN RT
$Git::CPAN::Patch::Command::SendEmail::VERSION = '2.3.3';
use 5.10.0;

use strict;
use warnings;

use MooseX::App::Command;

with 'Git::CPAN::Patch::Role::Git';
with 'Git::CPAN::Patch::Role::Patch';

parameter extra_arg => (
    is => 'rw',
    isa => 'Str',
    required => 0,
);

sub run { $_[0]->send_emails($_[0]->extra_arg) }

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Git::CPAN::Patch::Command::SendEmail - use C<git-send-email> to submit patches to CPAN RT

=head1 VERSION

version 2.3.3

=head1 SYNOPSIS

    % git-cpan send_email

=head1 DESCRIPTION

This command provides a C<--to> parameter to C<git send-email> that corresponds
to the RT queue of the imported module.

=head1 AUTHOR

Yanick Champoux <yanick@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2018, 2017, 2016, 2015, 2014, 2013, 2012, 2011, 2010, 2009 by Yanick Champoux.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
