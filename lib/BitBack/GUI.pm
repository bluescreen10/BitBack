package BitBack::GUI;

use strict;
use warnings;
use Gtk2 '-init';
use Data::Dumper;

use constant {
    FATAL => 'FATAL',
    INFO  => 'INFO',
    WARN  => 'WARN',
    DEBUG => 'DEBUG',
};

sub new {
    my $class = shift;

    my $self = bless {}, $class;
    $self->initialize(@_);

    return $self;
}

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

sub info {
    my ( $self, $message ) = @_;
    $self->_append_debug( WARN, $message );
}

sub initialize {
    my ( $self, $model ) = @_;

    # model
    $self->{model} = $model;
    $model->notify($self);

    my $file = __FILE__;
    $file =~ s/\.pm$/\.glade/;

    $self->{builder} = Gtk2::Builder->new;
    $self->{builder}->add_from_file($file);
    $self->_connect_signals;

}

sub start {
    my $self = shift;

    $self->{model}->initialize;

    my $window = $self->{builder}->get_object("main_window");
    $window->show();
    Gtk2->main();
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
            1 => $_->status,
            2 => $_->last_run,
            3 => $_->last_success,
        );
        $index++;
    }

}

sub changed_percentage {
    my $self         = shift;
    my $progress_bar = $self->{builder}->get_object('run_progress');
    $progress_bar->set_fraction( $self->{model}->percentage );
    $self->_update_view;
}

sub _close_error_dialog {
    my $self = shift;

    my $dialog = $self->{builder}->get_object("error_dialog");
    $dialog->hide;
    return Gtk2::EVENT_STOP;
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
    $builder->get_object("debug_menu_item")->signal_connect( "activate" => sub { $self->_show_debug_window } );

    #Error dialog
    $builder->get_object("error_dialog")->signal_connect( "delete-event" => sub { $self->_close_error_dialog } );

    $builder->get_object("new_button")->signal_connect( "clicked" => sub { $self->_new_profile } );
    $builder->get_object("run_button")->signal_connect( "clicked" => sub { $self->_run_profile } );
    $builder->get_object("profiles_list")->signal_connect( "cursor-changed" => sub { $self->_profile_selected } );
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

    $run->set_sensitive($status);
    $restore->set_sensitive($status);
    $edit->set_sensitive($status);
    $remove->set_sensitive($status);
}

sub _new_profile {
    my $self = shift;
}

sub _run_profile {
    my $self = shift;

    my $run     = $self->{builder}->get_object("run_button");
    my $restore = $self->{builder}->get_object("restore_button");
    my $list    = $self->{builder}->get_object("profiles_list");
    my ( $model, $iter ) = $list->get_selection->get_selected;
    my $profile = $model->get( $iter, 0 );

    $run->set_sensitive(0);
    $restore->set_sensitive(0);
    $list->get_selection->unselect_all;
    $self->_update_view;
    $self->{model}->run($profile);

    #    $run->set_sensitive(1);
    #    $restore->set_sensitive(1);
}

sub _show_debug_window {
    my $self = shift;

    my $window = $self->{builder}->get_object("debug_window");
    $window->show;

}

1;
