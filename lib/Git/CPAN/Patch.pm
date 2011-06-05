package Git::CPAN::Patch;
BEGIN {
  $Git::CPAN::Patch::AUTHORITY = 'cpan:yanick';
}
BEGIN {
  $Git::CPAN::Patch::VERSION = '0.6.1';
}

use strict;
use warnings;

'end of module Git::CPAN::Patch';

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

    % git commit -am "blah"
    % git cpan-sendpatch --compose



    # update the module
    # this automatically rebases the current branch
    % git cpan-update

=head1 DESCRIPTION

L<Git::CPAN::Patch> provides a suite of git commands
aimed at making trivially 
easy the process of  grabbing 
any distribution off CPAN, stuffing it 
in a local git repository and, once gleeful
hacking has been perpetrated, sending back
patches to its maintainer.  

=head1 GIT COMMANDS

=over

=item L<git-cpan-init>    

Create a git repository for a CPAN module

=item L<git-backpan-init> 

Initialize a repository for a CPAN module with full history
from the backpan.

=item L<git-cpan-import>  

Import a module into a git repository.

=item L<git-cpan-last-version>

Report the last imported version

=item L<git-cpan-send-email>    

Use C<git-send-email> to submit patches to CPAN RT

=item L<git-cpan-sendpatch>  

Create patch files and submit then to RT

=item L<git-cpan-update>

Import the latest version of a module and rebase the current branch

=item L<git-cpan-format-patch>  

Format patches using C<cpan/master> as the origin reference

=item L<git-cpan-squash>

Combine multiple commits into one patch

=item L<git-cpan-which> 

Report the managed module

=back


=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-git-cpan-patch@rt.cpan.org>, or through the web 
interface at L<http://rt.cpan.org>.

  
=head1 AUTHORS

Yanick Champoux C<< <yanick@cpan.org> >>

Yuval Kogman C<< <nothingmuch@woobling.org> >>

=head1 LICENCE

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 SEE ALSO

=head2

=over

=item L<git-backpan-init>       

=item L<git-cpan-import>  

=item L<git-cpan-last-version>

=item L<git-cpan-sendpatch>  

=item L<git-cpan-update>

=item L<git-cpan-format-patch>  

=item L<git-cpan-init>    

=item L<git-cpan-send-email>    

=item L<git-cpan-squash>

=item L<git-cpan-which>

=back 


=head2 Articles

The set of scripts that would eventually become 
L<Git::CPAN::Patch> were first presented in the 
article I<CPAN Patching with Git>, published in 
issue 5.1 of L<The Perl Review|http://theperlreview.com>.

=head2 Git::CPAN::Patch on the Net

=over

=item On CPAN

http://search.cpan.org/dist/Git-CPAN-Patch

=item Bug tracker

http://rt.cpan.org/Public/Dist/Display.html?Name=Git-CPAN-Patch

=item Github git repository

web interface: http://github.com/yanick/git-cpan-patch

to clone:  

  $ git clone git://github.com/yanick/git-cpan-patch.git

=back


=cut


