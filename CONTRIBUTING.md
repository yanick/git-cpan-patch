
# Contributing to Git-CPAN-Patch

So you want to contribute to this package? Or fork it? Or play with it, or
whatever? Excellent! Here, let me try to make it easier for you.

## Dist::Zilla and branch structure

This package, like many of mine, uses [Dist::Zilla](https://metacpan.org/dist/Dist-Zilla).
Dist::Zilla (`dzil` to its friends) is a distribution builder 
that helps (tremendously) with the nitty gritty of grooming 
and releasing packages to CPAN. It tidies up the
documentation, add boilerplate files, update versions,
and... do a *bunch* of other things. Because it does so
much, it can be scary for some people. But it really doesn't need
to be. 

This repository has two core branches:

* `main` -- the working branch, holding the pre-dzil-munging code. 

* `releases` -- contains the dzil-munged code released to
CPAN.

Which means that if you don't want to bother with
Dist::Zilla at all, checkout `releases` and work on it.
Since it's the "real" code that made it to CPAN, all it
working -- the package itself, the tests, everything. And
totally feel free to use this branch as a base for a PR.
I'll be very grateful for the work, and I'll take on the last
step of porting the patching to `main`, noooo problem.

### I'm brave, I want to be on `main`

Good for you! 

The good news is that dzil mostly tinker with stuff the 
working code doesn't care about, so you probably won't have
to do anything special. In most cases, tinkering with the
code will look like:

    $ cpanm --installdeps . 
    $ ... tinker, tinker ...
    $ prove -l t 

Now, if you want to generate the CPAN-ready tarball, or go
full YANICK on things. You'll have to install both
Dist::Zilla and my plugin bundle:

    $ cpanm Dist::Zilla Dist::Zilla::PluginBundle::YANICK

and then you should be able to do all things dzilly;

    # generate the tarball 
    $ dzil build 

    # run all the tests on the final code 
    $ dzil test 

Now, a honest caveat: `Dist::Zilla::PluginBundle::YANICK` is
tailored to my exact needs; it does a lot, and some of it
is not guaranteed to work on somebody else's system. If you
try to use it and you hit something weird, just let me know,
and I'll do my best to help you.

Aaaand that's pretty all I think you need to get started. Good luck! :-)
