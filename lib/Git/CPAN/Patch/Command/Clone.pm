package Git::CPAN::Patch::Command::Clone;
BEGIN {
  $Git::CPAN::Patch::Command::Clone::AUTHORITY = 'cpan:YANICK';
}
{
  $Git::CPAN::Patch::Command::Clone::VERSION = '1.3.1';
}
#ABSTRACT: Clone a CPAN module's history into a new git repository

use 5.10.0;

use strict;
use warnings;

use autodie;
use Path::Class;
use Method::Signatures::Simple;

use MooseX::App::Command;
extends 'Git::CPAN::Patch::Command::Import';

parameter xtarget => (
    is       => 'rw',
    isa      => 'Str',
    required => 0,
);


before import_release => method($release) {
    state $first = 1;

    return unless $first;

    my $target = $self->target || $release->dist_name;

    say "creating $target";

    dir($target)->mkpath;
    Git::Repository->run( init => $target );
    $self->set_root($target);

    $first = 0;
};

after import_release => method {
    $self->git_run( 'reset', '--hard', $self->last_commit );    
};

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

  % git-cpan clone Foo::Bar 
  % git-cpan clone Foo-Bar-0.03.tar.gz 
  % git-cpan clone http://... 
  % git-cpan clone /path/to/Foo-Bar-0.03.tar.gz

=head1 DESCRIPTION

This command creates the named directory, creates a new git repository, calls
C<git-cpan-init>, and then checks out the code in the C<master> branch. If the
directory is omitted, then the "humanish" part of the named module is used.

  
=head1 AUTHORS

Mike Doherty C<< <doherty@cpan.org> >>

Yanick Champoux C<< <yanick@cpan.org> >>

=head1 SEE ALSO

L<Git::CPAN::Patch>, L<git-cpan-init>, L<git-cpan-import>

=cut
