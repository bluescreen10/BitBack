#!perl

use strict;
use warnings;
use ExtUtils::MakeMaker;

# Write Makefile
WriteMakefile(
    NAME         => 'BitBack',
    ABSTRACT     => 'Multi Platform Backup Utility',
    AUTHOR       => 'Mariano Wahlmann <dichoso@gmail.com>',
    VERSION_FROM => 'lib/BitBack.pm',
    PREREQ_PM    => {
        'Test::More'    => 0,
        'Gtk2'          => 0,
    },
    EXE_FILES => ['bin/bitback'],
    test      => { TESTS => 't/*.t' }
);
