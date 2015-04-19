requires "Archive::Any" => "0";
requires "Archive::Extract" => "0";
requires "BackPAN::Index" => "0";
requires "CLASS" => "0";
requires "CPAN::Meta" => "0";
requires "CPAN::ParseDistribution" => "0";
requires "CPANPLUS" => "0";
requires "Cwd" => "0";
requires "DateTime" => "0";
requires "File::Basename" => "0";
requires "File::Copy" => "0";
requires "File::Find" => "0";
requires "File::Path" => "0";
requires "File::Spec::Functions" => "0";
requires "File::Temp" => "0";
requires "File::chdir" => "0";
requires "File::chmod" => "0";
requires "Git::Repository" => "0";
requires "Git::Repository::Plugin::AUTOLOAD" => "0";
requires "LWP::Simple" => "0";
requires "LWP::UserAgent" => "0";
requires "List::Pairwise" => "0";
requires "MetaCPAN::API" => "0";
requires "MetaCPAN::Client" => "0";
requires "Method::Signatures::Simple" => "1.07";
requires "Moose" => "0";
requires "Moose::Role" => "0";
requires "MooseX::App" => "1.21";
requires "MooseX::App::Command" => "0";
requires "MooseX::App::Role" => "0";
requires "MooseX::Role::Tempdir" => "0";
requires "MooseX::SemiAffordanceAccessor" => "0";
requires "Path::Class" => "0";
requires "Path::Tiny" => "0";
requires "Pod::Usage" => "0";
requires "autodie" => "0";
requires "experimental" => "0";
requires "perl" => "v5.10.1";
requires "strict" => "0";
requires "version" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "Carp" => "0";
  requires "DDP" => "0";
  requires "File::Spec" => "0";
  requires "IO::Handle" => "0";
  requires "IPC::Open3" => "0";
  requires "Test::MockObject" => "0";
  requires "Test::More" => "0.88";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "version" => "0.9901";
};
