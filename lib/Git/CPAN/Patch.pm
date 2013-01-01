package Git::CPAN::Patch;
#ABSTRACT: Patch CPAN modules using Git

use strict;
use warnings;

{
    no warnings 'redefine';

    use MooseX::App::Utils;
    use MooseX::App::Meta::Role::Class::Base;

    #FIXME very naughty monkeypatching
    my $orig = \&MooseX::App::Utils::class_to_command;
    *MooseX::App::Utils::class_to_command = sub {
        my $result = $orig->(@_);
        $result =~ y/_/-/;
        return $result;
    };

    package   # hide from PAUSE
        MooseX::App::Meta::Role::Class::Base;

    sub command_usage_header {
        my ($self,$command_meta_class) = @_;
    
        my $caller = $self->app_base;
        my $command;

        if ( $command_meta_class ) {
            my $command_class = $command_meta_class->name;
            $command = $self->command_class_to_command($command_class);

            # for a proof of concept, let's go hard-core
            $command_class =~ s#::#/#g;
            $command_class .= ".pm";

            if( open my $fh, '<', $INC{$command_class} ) {
            my $content = do { local $/ = <$fh> };

            return $self->command_message(
                header  => 'usage:',
                body    => $1 ) 
                if $content =~ m#^=head1\s+SYNOPSIS.*?\n(.*?)(?:^=|\Z)#sm;
            }
        }

        $command ||= 'command';
        
        return $self->command_message(
            header  => 'usage:',
            body    => MooseX::App::Utils::format_text("$caller $command [long options...]
$caller help
$caller $command --help"));
    }

    sub command_usage_command {
        my ($self,$command_meta_class) = @_;
        
        $command_meta_class ||= $self;
        
        my $command_class = $command_meta_class->name;
        my $command_name = $self->command_class_to_command($command_class);
        
        my @usage;
        push(@usage,$self->command_usage_header($command_meta_class));
        push(@usage,$self->command_usage_description($command_meta_class));
        push(@usage,$self->command_usage_attributes($command_meta_class));
        
        return @usage;
    }
}

use MooseX::App;
use MooseX::SemiAffordanceAccessor;

use MetaCPAN::API;
use Method::Signatures;

app_base 'git-cpan';
app_namespace 'Git::CPAN::Patch::Command';

option man => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
    lazy => 1,
    trigger => sub { 
        require Pod::Usage;
        my $name = $_[0]->meta->name . '.pm';
        $name =~ s#::#/#g;

        exit Pod::Usage::pod2usage(
            -verbose => 2, 
            -input => $INC{$name}
        );
    },
    documentation => q{Prints the command's manpage},
);

has target => (
    is => 'rw',
    isa => 'Str',
);

has distribution_name => (
    is => 'ro',
    lazy_build => 1,
);

has distribution_meta => (
    isa => 'HashRef',
    is => 'ro',
    lazy_build => 1,
);

has repo => (
    is => 'ro',
    lazy_build => 1,
);

method _build_repo {
    Git::Repository->new( );
}

method _build_distribution_name {
    my $target = $self->target;

    $target =~ s/-/::/g;

    my $mcpan = MetaCPAN::API->new;

    return  $mcpan->module( $target )->{distribution};
}

method _build_distribution_meta {
    my $mcpan = MetaCPAN::API->new;

    $mcpan->release( distribution => $self->distribution_name );
}

__PACKAGE__->meta->make_immutable;

'end of module Git::CPAN::Patch';

__END__

# TODO add back --compose to sendpatch


=head1 SYNOPSIS

    # import a module:

    % git-cpan clone Foo::Bar
    % cd Foo-Bar

    # hack and submit to RT

    # it's probably best to work in a branch
    % git checkout -b blah

    ... hack lib/Foo/Bar.pm ...

    % git commit -am "blah"
    % git-cpan sendpatch 

    # update the module
    # this automatically rebases the current branch
    % git-cpan update

=head1 DESCRIPTION

L<Git::CPAN::Patch> provides a suite of git commands
aimed at making trivially
easy the process of  grabbing
any distribution off CPAN, stuffing it
in a local git repository and, once gleeful
hacking has been perpetrated, sending back
patches to its maintainer.

=head1 GIT-CPAN COMMANDS

=over

=item L<clone|Git::CPAN::Patch::Command::Clone>

Clone a CPAN module's history into a new git repository

=item L<import|Git::CPAN::Patch::Command::Import>

Import a module into a git repository.

=item L<send-email|Git::CPAN::Patch::Command::SendEmail>

Use C<git-send-email> to submit patches to CPAN RT

=item L<send-patch|Git::CPAN::Patch::Command::SendPatch>

Create patch files and submit then to RT

=item L<update|Git::CPAN::Patch::Command::Update>

Import the latest version of a module and rebase the current branch

=item L<format-patch|Git::CPAN::Patch::Command::FormatPatch>

Format patches using C<cpan/master> as the origin reference

=item L<squash|Git::CPAN::Patch::Command::Squash>

Combine multiple commits into one patch

=item L<which|Git::CPAN::Patch::Command::Which>

Report upon the managed module

=back

=head1 AUTHORS

Yanick Champoux C<< <yanick@cpan.org> >>

Yuval Kogman C<< <nothingmuch@woobling.org> >>

=head1 SEE ALSO

=head2 Articles

The set of scripts that would eventually become
L<Git::CPAN::Patch> were first presented in the
article I<CPAN Patching with Git>, published in
issue 5.1 of L<The Perl Review|http://theperlreview.com>.

=cut


