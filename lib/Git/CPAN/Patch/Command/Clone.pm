package Git::CPAN::Patch::Command::Clone;
our $AUTHORITY = 'cpan:YANICK';
#ABSTRACT: Clone a CPAN module's history into a new git repository
$Git::CPAN::Patch::Command::Clone::VERSION = '2.3.4';
use 5.20.0;

use strict;
use warnings;

use autodie;
use Path::Class;

use MooseX::App::Command;
extends 'Git::CPAN::Patch::Command::Import';

use experimental 'signatures';

parameter target => (
    is       => 'rw',
    isa      => 'Str',
    required => 0,
);

has _seen_imports => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);


before [ qw/import_release clone_git_repo /] => sub($self,$release,@) {
    return if $self->_seen_imports;
    $self->_set_seen_imports(1);

    my $target = $self->target || $release->dist_name;

    say "creating $target";

    dir($target)->mkpath;
    Git::Repository->run( init => $target );
    $self->set_root($target);
};

after [ qw/ clone_git_repo import_release /] => sub($self,@) {
    $self->git_run( 'reset', '--hard', $self->last_commit );
};

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Git::CPAN::Patch::Command::Clone - Clone a CPAN module's history into a new git repository

=head1 VERSION

version 2.3.4

=head1 SYNOPSIS

  # from a specific tarball
  $ git-cpan clone http://... 
  $ git-cpan clone /path/to/Foo-Bar-0.03.tar.gz

  # from CPAN, module and dist names are okay
  $ git-cpan clone Foo::Bar 
  $ git-cpan clone Foo-Bar 
   
  # can also specify the directory to create
  $ git-cpan clone Foo-Bar my_clone

=head1 DESCRIPTION

Clones a CPAN distribution. If a tarball is given, either locally or via an 
url, it'll be used. If not, C<git-cpan> will try to find the distribution or
module. If it has an official git repository, it'll be cloned. If not, the
history will be created using the CPAN releases.

If the target
directory is omitted, then the "humanish" part of the distribution is used.

=head1 AUTHORS

Mike Doherty C<< <doherty@cpan.org> >>

Yanick Champoux C<< <yanick@cpan.org> >>

=head1 SEE ALSO

L<Git::CPAN::Patch>, L<git-cpan-init>, L<git-cpan-import>

=head1 AUTHOR

Yanick Champoux <yanick@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2018, 2017, 2016, 2015, 2014, 2013, 2012, 2011, 2010, 2009 by Yanick Champoux.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
