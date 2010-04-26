use strict;
use warnings;

use Module::Build;

my $builder = Module::Build->new(
    module_name => 'Git::CPAN::Patch',
    license     => 'perl',
    dist_author => 'Yanick Champoux <yanick@cpan.org>',
    requires    => {
        perl                       => '5.010',
        'Module::Build'            => 0,
        'autodie'                  => 0,
        'BackPAN::Index'           => 0,
        'Pod::Usage'               => 0,
        'CPANPLUS'                 => '0.84',
        'File::chdir'              => 0,
        'File::Path'               => 0,
        'File::chmod'              => 0,
        'CLASS'                    => 0,
        'File::Temp'                => '0.22',
    },
    script_files => [
        map "scripts/$_"  => 'git-backpan-init',
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
    create_makefile_pl => 'small',
);

$builder->create_build_script();

return $builder if caller;   # so that it can be retrieved from within Dist::Release
