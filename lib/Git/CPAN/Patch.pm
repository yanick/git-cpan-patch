package Git::CPAN::Patch;

use strict;
use warnings;

our $VERSION = "0.1.0";

__END__

=pod

=head1 NAME

Git::CPAN::Patch - Patch CPAN modules using Git

=head1 SYNOPSIS

    # import a module:

    % mkdir Foo-Bar
    % cd Foo-Bar
    % git cpan-init Foo::Bar



    # hack and submit to RT

    # it's probably best to work in a branch
    % git checkout -b blah

    hack lib/Foo/Bar.pm

    % git ci -am "blah"
    % git cpan-sendpatch --compose



    # update the module
    # this automatically rebases the current branch
    % git cpan-update

=head1 DESCRIPTION

=cut


