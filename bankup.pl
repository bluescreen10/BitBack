#! /usr/bin/perl

use strict;
use Gtk2 '-init';
use Data::Dumper;

my $builder = Gtk2::Builder->new();
$builder->add_from_file('./src/gtkbuilder/bankup.glade');

my $window = $builder->get_object("main_window");
$builder->connect_signals(undef);

$window->show();

Gtk2->main();
Nin
exit;

sub cb_destroy {
    print STDERR "Hello\n";
    Gtk2->main_quit();

}

sub cb_clicked {
    my $progress_bar = $builder->get_object("progressbar1");
    $progress_bar->set_fraction(0.5);
    my $model = $builder->get_object("profiles_store");
    $model->insert_with_values( 3, 0 => "New", 1 => "None", 2 => "", 3 => ""  );

}

sub cb_main_window_about_clicked {
   my $dialog = $builder->get_object("about_dialog");
   $dialog->show;
}

sub cb_main_window_profile_selected {
    print Dumper(@_);
}

Gtk2->main;

