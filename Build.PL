use strict;
use warnings;

use Module::Build;

print <<END_MESSAGE;

>>>>>>>>>>>>  WARNING <<<<<<<<<<<<<<<<<

This Build.PL won't do the full install dance (yet).

For the time being, it's only here to let you know
if you have all the right dependencies installed.

END_MESSAGE

my $builder = Module::Build->new(
    module_name  => 'Git::CPAN::Patch',
    license      => 'perl',
    dist_author  => 'Yanick Champoux <yanick@cpan.org>',
    requires     => {
        perl                       => '5.10.0',
        'autodie'                  => 0,
        'Parse::BACKPAN::Packages' => 0,
    },
    script_files => [
        map "git-cpan-$_" => qw/
          format-patch  init          send-email
          squash        which         sendpatch
          import        last-version  update
          /
    ],

    meta_merge => {
        resources => {
            repository => 'git://github.com/yanick/git-cpan-patch.git',
            bugtracker =>
              'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Git-CPAN-Patch',
        },
    },
);

$builder->create_build_script();
