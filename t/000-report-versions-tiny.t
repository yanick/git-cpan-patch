use strict;
use warnings;
use Test::More 0.88;
# This is a relatively nice way to avoid Test::NoWarnings breaking our
# expectations by adding extra tests, without using no_plan.  It also helps
# avoid any other test module that feels introducing random tests, or even
# test plans, is a nice idea.
our $success = 0;
END { $success && done_testing; }

# List our own version used to generate this
my $v = "\nGenerated by Dist::Zilla::Plugin::ReportVersions::Tiny v1.08\n";

eval {                     # no excuses!
    # report our Perl details
    my $want = 'v5.10.1';
    $v .= "perl: $] (wanted $want) on $^O from $^X\n\n";
};
defined($@) and diag("$@");

# Now, our module version dependencies:
sub pmver {
    my ($module, $wanted) = @_;
    $wanted = " (want $wanted)";
    my $pmver;
    eval "require $module;";
    if ($@) {
        if ($@ =~ m/Can't locate .* in \@INC/) {
            $pmver = 'module not found.';
        } else {
            diag("${module}: $@");
            $pmver = 'died during require.';
        }
    } else {
        my $version;
        eval { $version = $module->VERSION; };
        if ($@) {
            diag("${module}: $@");
            $pmver = 'died during VERSION check.';
        } elsif (defined $version) {
            $pmver = "$version";
        } else {
            $pmver = '<undef>';
        }
    }

    # So, we should be good, right?
    return sprintf('%-45s => %-10s%-15s%s', $module, $pmver, $wanted, "\n");
}

eval { $v .= pmver('Archive::Extract','any version') };
eval { $v .= pmver('BackPAN::Index','any version') };
eval { $v .= pmver('CLASS','any version') };
eval { $v .= pmver('CPAN::Meta','any version') };
eval { $v .= pmver('CPAN::ParseDistribution','any version') };
eval { $v .= pmver('CPANPLUS','any version') };
eval { $v .= pmver('Cwd','any version') };
eval { $v .= pmver('DateTime','any version') };
eval { $v .= pmver('File::Basename','any version') };
eval { $v .= pmver('File::Copy','any version') };
eval { $v .= pmver('File::Find','any version') };
eval { $v .= pmver('File::Path','any version') };
eval { $v .= pmver('File::Spec','any version') };
eval { $v .= pmver('File::Spec::Functions','any version') };
eval { $v .= pmver('File::Temp','any version') };
eval { $v .= pmver('File::chdir','any version') };
eval { $v .= pmver('File::chmod','any version') };
eval { $v .= pmver('Git::Repository','any version') };
eval { $v .= pmver('Git::Repository::Plugin::AUTOLOAD','any version') };
eval { $v .= pmver('IO::Handle','any version') };
eval { $v .= pmver('IPC::Open3','any version') };
eval { $v .= pmver('LWP::Simple','any version') };
eval { $v .= pmver('LWP::UserAgent','any version') };
eval { $v .= pmver('List::Pairwise','any version') };
eval { $v .= pmver('MetaCPAN::API','any version') };
eval { $v .= pmver('Method::Signatures::Simple','1.07') };
eval { $v .= pmver('Module::Build','0.3601') };
eval { $v .= pmver('Moose','any version') };
eval { $v .= pmver('Moose::Role','any version') };
eval { $v .= pmver('MooseX::App','1.21') };
eval { $v .= pmver('MooseX::App::Command','any version') };
eval { $v .= pmver('MooseX::App::Role','any version') };
eval { $v .= pmver('MooseX::Role::Tempdir','any version') };
eval { $v .= pmver('MooseX::SemiAffordanceAccessor','any version') };
eval { $v .= pmver('Path::Class','any version') };
eval { $v .= pmver('Pod::Usage','any version') };
eval { $v .= pmver('Test::MockObject','any version') };
eval { $v .= pmver('Test::More','0.88') };
eval { $v .= pmver('autodie','any version') };
eval { $v .= pmver('experimental','any version') };
eval { $v .= pmver('strict','any version') };
eval { $v .= pmver('version','0.9901') };
eval { $v .= pmver('warnings','any version') };


# All done.
$v .= <<'EOT';

Thanks for using my code.  I hope it works for you.
If not, please try and include this output in the bug report.
That will help me reproduce the issue and solve your problem.

EOT

diag($v);
ok(1, "we really didn't test anything, just reporting data");
$success = 1;

# Work around another nasty module on CPAN. :/
no warnings 'once';
$Template::Test::NO_FLUSH = 1;
exit 0;
