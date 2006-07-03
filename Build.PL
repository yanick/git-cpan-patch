use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Language::l33t',
    license             => 'perl',
    dist_author         => 'Yanick Champoux <yanick@cpan.org>',
    dist_version_from   => 'lib/Language/l33t.pm',
    build_requires => {
        'Class::Std'       => 0,
        'Readonly'         => 0,
        'Carp'             => 0,
        'IO'               => 0,
        'Test::More'       => 0,
    },
    add_to_cleanup      => [ 'Language::l33t-*' ],
    create_makefile_pl  => 'traditional',
);

$builder->create_build_script();
