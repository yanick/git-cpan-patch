
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Carp" => 0,
    "Module::Build" => "0.3601",
    "Scalar::Util" => 0,
    "Test::Compile" => 0,
    "Test::More" => "0.94"
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "Patch CPAN modules using Git",
  "dist_author" => [
    "Yanick Champoux <yanick\@cpan.org>"
  ],
  "dist_name" => "Git-CPAN-Patch",
  "dist_version" => "0.8.0",
  "license" => "perl",
  "module_name" => "Git::CPAN::Patch",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Archive::Extract" => 0,
    "BackPAN::Index" => 0,
    "CLASS" => 0,
    "CPANPLUS" => 0,
    "Cwd" => 0,
    "DateTime::Format::W3CDTF" => 0,
    "File::Basename" => 0,
    "File::Find" => 0,
    "File::Path" => 0,
    "File::Spec::Functions" => 0,
    "File::Temp" => 0,
    "File::chdir" => 0,
    "File::chmod" => 0,
    "Getopt::Long" => 0,
    "Git::Repository" => 0,
    "LWP::UserAgent" => 0,
    "MetaCPAN::API" => 0,
    "Method::Signatures" => 0,
    "Moose" => 0,
    "MooseX::App::Cmd" => 0,
    "MooseX::App::Cmd::Command" => 0,
    "MooseX::SemiAffordanceAccessor" => 0,
    "Pod::Usage" => 0,
    "autodie" => 0,
    "perl" => "v5.10.0",
    "strict" => 0,
    "version" => 0,
    "warnings" => 0
  },
  "script_files" => [
    "bin/git-backpan-init",
    "bin/git-cpan-which",
    "bin/git-cpan-sendpatch",
    "bin/git-cpan-format-patch",
    "bin/git-cpan-squash",
    "bin/git-cpan-send-email",
    "bin/git-cpan-init",
    "bin/git-cpan-import",
    "bin/git-cpan-sources",
    "bin/git-cpan-update",
    "bin/git-cpan-last-version",
    "bin/git-cpan-clone"
  ]
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
