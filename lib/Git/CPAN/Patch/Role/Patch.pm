package Git::CPAN::Patch::Role::Patch;

use 5.10.0;

use strict;
use warnings;

use Method::Signatures::Simple;

use Moose::Role;

requires 'git_run';

has patches => (
    is => 'rw',
    traits => [ 'Array' ],
    isa => 'ArrayRef',
    default => method { [
        $self->git_run( 'format-patch', 'cpan/master' )
    ] },
    handles => {
        add_patches => 'push',
        all_patches => 'elements',
        nbr_patches => 'count',
    },
);

method format_patch {
    say for $self->all_patches;
}

has module_name => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => method {

        if (my $module = $self->git->run('config', 'cpan.module-name')) {
            return $module
        }

        my $last_commit = $self->git->run('rev-parse', '--verify', 'cpan/master');

        my $last = join "\n", $self->git->run( log => '--pretty=format:%b', '-n', 1, $last_commit );

        $last =~ /git-cpan-module: \s+ (.*?) \s+ git-cpan-version: \s+ (.*?) \s*$/sx
            or die "Couldn't parse message (not cloned via git cpan import?):\n$last\n";

        $self->git->run('config', 'cpan.module-name', $1);

        return $1;
    },
);

method send_emails(@patches) {
    my $to = 'bug-' . $self->module_name . '@rt.cpan.org';

    say for $self->git_run("send-email", '--no-chain-reply-to', "--to", $to,
    @patches );
}

1;

__END__



