package BitBack::GUI::Gtk;

use strict;
use warnings;
use Glib;
use Gtk2 qw(-init);
use Data::Dumper;
use base qw(BitBack::GUI);
Glib::Object->set_threadsafe(1);

my $selected_profile;

use constant {
    FATAL => 'FATAL',
    INFO  => 'INFO',
    WARN  => 'WARN',
    DEBUG => 'DEBUG',
};

sub fatal {
    my ( $self, $message ) = @_;

    my $dialog = $self->{builder}->get_object("error_dialog");
    $self->_append_debug( FATAL, $message );
    $dialog->set_markup($message);
    $dialog->show;
}

sub info {
    my ( $self, $message ) = @_;
    $self->_append_debug( INFO, $message );
}

sub warn {
    my ( $self, $message ) = @_;
    $self->_append_debug( WARN, $message );
}

sub start {
    my $self = shift;

    $self->SUPER::start();

    Glib::Idle->add( sub { $self->process_events;return 1 } );
    my $window = $self->{builder}->get_object("main_window");
    $window->show();
    Gtk2->main();
    $self->{model}->clean_up;
}

sub changed {
    my ( $self, $aspect ) = @_;
    my $method = "changed_$aspect";
    if ( $self->can($method) ) {
        $self->$method();
        $self->_update_view;
    }
}

sub changed_profiles {
    my $self = shift;

    my $store = $self->{builder}->get_object("profiles_store");

    $store->clear;

    my $index = 1;
    foreach ( @{ $self->{model}->profiles } ) {
        $store->insert_with_values(
            $index,
            0 => $_->name,
            1 => $_->percentage,
            2 => $_->last_run,
            3 => $_->last_success,
            4 => $_->is_running,
        );
        $index++;
    }

}

sub changed_percentage {
    my $self         = shift;
    my $list = $self->_ui_widget("profiles_list");
    my @paths = $list->get_selection->get_selected_rows;
    $self->changed_profiles;
    $list->get_selection->select_path(@paths);
    $self->_update_view;
}

sub _close_error_dialog {
    my $self = shift;

    my $dialog = $self->{builder}->get_object("error_dialog");
    $dialog->hide;
    return Gtk2::EVENT_STOP;
}

sub _init {
    my $self = shift;

    $self->SUPER::_init();

    my $file = __FILE__;
    $file =~ s/\.pm$/\/GUI\.glade/;

    $self->{builder} = Gtk2::Builder->new;
    $self->{builder}->add_from_file($file);
    $self->_connect_signals;
}

sub _update_view {

    # updates the view
    while ( Gtk2->events_pending ) {
        Gtk2->main_iteration;
    }

}

sub _connect_signals {
    my $self = shift;

    my $builder = $self->{builder};

    #Menu
    $builder->get_object("debug_menu_item")
      ->signal_connect( "activate" => sub { $self->_show_debug_window } );

    #Error dialog
    $builder->get_object("error_dialog")
      ->signal_connect( "delete-event" => sub { $self->_close_error_dialog } );


    # Main window
    $self->_connect_main_window_signals;
}

sub _connect_main_window_signals {
    my $self = shift;

    # Window
    my $widget = $self->_ui_widget("main_window");
    $widget->signal_connect( "destroy" => sub { $self->_quit });

    # New button
    $widget = $self->_ui_widget("new_button");
    $widget->signal_connect( "clicked" => sub { $self->_new_profile } );

    # Run Button
    $widget = $self->_ui_widget("run_button");
    $widget->signal_connect( "clicked" => sub { $self->_archive_profile } );

    # Profiles List
    $widget = $self->_ui_widget("profiles_list");
    $widget->signal_connect( "cursor-changed" => sub { $self->_profile_selected } );


}

sub _ui_widget {
    my ( $self, $name ) = @_;
    $self->{builder}->get_object($name);
}

sub _append_debug {
    my ( $self, $type, $message, $level ) = @_;

    if ($level) {
        $level = "($level)";
    }
    else {
        $level = '';
    }

    my $buffer = $self->{builder}->get_object("debug_buffer");
    $buffer->insert_at_cursor("$type$level: $message\n");

}

# Signals

sub _profile_selected {
    my $self = shift;

    my $list = $self->{builder}->get_object("profiles_list");
    my ( $model, $iter ) = $list->get_selection->get_selected;

    my $run     = $self->{builder}->get_object("run_button");
    my $restore = $self->{builder}->get_object("restore_button");
    my $edit    = $self->{builder}->get_object("edit_button");
    my $remove  = $self->{builder}->get_object("remove_button");

    my $status = defined($model);

    if ( $model ) {
        $selected_profile = $model->get( $iter, 0 );
    }
    else {
        $selected_profile = undef;
    }

    $run->set_sensitive($status);
    $restore->set_sensitive($status);
    $edit->set_sensitive($status);
    $remove->set_sensitive($status);
}

sub _new_profile {
    my $self = shift;
}

sub _archive_profile {
    my $self = shift;

    my $run     = $self->{builder}->get_object("run_button");
    my $restore = $self->{builder}->get_object("restore_button");
    $self->{model}->archive($selected_profile);
}

sub _show_debug_window {
    my $self = shift;

    my $window = $self->{builder}->get_object("debug_window");
    $window->show;

}

sub _quit {
    my $self = shift;
    if ( $self->{model}->is_running ) {
        # Alert the user if he wants to kill the running threads
        $self->_force_quit;
    }
    else {
        Gtk2->main_quit;
    }
}

sub _force_quit {
    my $self = shift;
    $self->{model}->force_quit;
    Gtk2->main_quit;
}

1;
