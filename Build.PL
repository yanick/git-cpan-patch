
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.3601",
    "Test::More" => "0.88"
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "Patch CPAN modules using Git",
  "dist_author" => [
    "Yanick Champoux <yanick\@cpan.org>"
  ],
  "dist_name" => "Git-CPAN-Patch",
  "dist_version" => "1.2.0",
  "license" => "perl",
  "module_name" => "Git::CPAN::Patch",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Archive::Extract" => 0,
    "BackPAN::Index" => 0,
    "CLASS" => 0,
    "CPAN::Meta" => 0,
    "CPAN::ParseDistribution" => 0,
    "CPANPLUS" => 0,
    "Cwd" => 0,
    "DateTime" => 0,
    "File::Basename" => 0,
    "File::Find" => 0,
    "File::Path" => 0,
    "File::Spec::Functions" => 0,
    "File::Temp" => 0,
    "File::chdir" => 0,
    "File::chmod" => 0,
    "Git::Repository" => 0,
    "LWP::Simple" => 0,
    "LWP::UserAgent" => 0,
    "List::Pairwise" => 0,
    "MetaCPAN::API" => 0,
    "Method::Signatures::Simple" => "1.07",
    "Moose" => 0,
    "Moose::Role" => 0,
    "MooseX::App" => "1.21",
    "MooseX::App::Command" => 0,
    "MooseX::App::Role" => 0,
    "MooseX::Role::Tempdir" => 0,
    "MooseX::SemiAffordanceAccessor" => 0,
    "Path::Class" => 0,
    "Pod::Usage" => 0,
    "autodie" => 0,
    "perl" => "v5.10.0",
    "strict" => 0,
    "version" => 0,
    "warnings" => 0
  },
  "script_files" => [
    "bin/git-cpan"
  ]
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
