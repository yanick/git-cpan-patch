
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  'build_requires' => {
    'Carp' => '0',
    'Module::Build' => '0.3601',
    'Scalar::Util' => '0',
    'Test::Compile' => '0',
    'Test::More' => '0.94'
  },
  'configure_requires' => {
    'Module::Build' => '0.3601'
  },
  'dist_abstract' => 'Patch CPAN modules using Git',
  'dist_author' => [
    'Yanick Champoux <yanick@cpan.org>'
  ],
  'dist_name' => 'Git-CPAN-Patch',
  'dist_version' => '0.6.1',
  'license' => 'perl',
  'module_name' => 'Git::CPAN::Patch',
  'recommends' => {},
  'recursive_test_files' => 1,
  'requires' => {
    'Archive::Extract' => '0',
    'BackPAN::Index' => '0',
    'CLASS' => '0',
    'CPANPLUS' => '0',
    'Cwd' => '0',
    'File::Basename' => '0',
    'File::Find' => '0',
    'File::Path' => '0',
    'File::Spec::Functions' => '0',
    'File::Temp' => '0',
    'File::chdir' => '0',
    'File::chmod' => '0',
    'Getopt::Long' => '0',
    'Git::Repository' => '0',
    'LWP::UserAgent' => '0',
    'Pod::Usage' => '0',
    'autodie' => '0',
    'perl' => '5.10.0',
    'version' => '0'
  },
  'script_files' => [
    'bin/git-backpan-init',
    'bin/git-cpan-format-patch',
    'bin/git-cpan-import',
    'bin/git-cpan-init',
    'bin/git-cpan-last-version',
    'bin/git-cpan-send-email',
    'bin/git-cpan-sendpatch',
    'bin/git-cpan-squash',
    'bin/git-cpan-update',
    'bin/git-cpan-which'
  ]
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
