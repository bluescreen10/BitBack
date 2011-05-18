package BitBack;

use strict;
use warnings;
use version;
use BitBack::ProfilesManager;
use threads;# 'exit' => 'threads_only';
use BitBack::Archiver::IndividualCompressedFiles;

our $VERSION = qq(1.00);

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->_init(@_);
    return $self;
}

sub changed {
    my ( $self, $aspect ) = @_;

    #Propagate change
    $self->_changed($aspect);
}

sub clean_up {
    foreach( threads->list(threads::joinable)) {
        $_->join;
    }
}

sub force_quit {
    foreach( threads->list(threads::running)) {
        $_->kill('SIGKILL')->detach;
    }
}

sub archive {
    my ( $self, $name ) = @_;

    my $profile = $self->{profiles_manager}->profile_named($name);

    unless ($profile) {
        $self->_fatal("Profile \"$name\" does not exists");
        return;
    }

    threads->create(
        sub {
            $self->_info("Archiving \"$name\"");

            # Handle Kill Event
            $SIG{'KILL'} = sub { return };

            my $strategy = $self->_strategy_for($profile);
            $strategy->archive;

            foreach ( @{ $strategy->errors } ) {
                $self->_warn($_);
            }

            $self->_info("Finished \"$name\"");
        }
    );
}

sub is_running {
    return scalar(threads->list(threads::running));
}

sub notify {
    my ( $self, $target ) = @_;
    $self->{listener} = $target;
}

sub profiles {
    my $self = shift;

    $self->{profiles_manager}->profiles;
}

sub read_config {
    my $self = shift;

    $self->{profiles_manager}->notify($self);

    eval { $self->{profiles_manager}->read_config; };

    if ($@) {
        $self->_fatal($@);
    }

}

sub restore {
    my ( $self, $name ) = @_;

    my $profile = $self->{profiles_manager}->profile_named($name);

    unless ($profile) {
        $self->_fatal("Profile \"$name\" does not exists");
    }

    $self->_info("Restoring \"$name\"");

    my $strategy = $self->_strategy_for($profile);
    $strategy->restore;

    foreach ( @{ $strategy->errors } ) {
        $self->_warn($_);
    }

    $self->_info('Finished');

}

sub _init {
    my ( $self, $options ) = @_;

    $self->{options}  = $options;
    $self->{listener} = [];
    $self->{profiles_manager} =
      BitBack::ProfilesManager->new( $options->{config} );
    $self->{percentage} = 0;
    $self->{running}    = 0;
}

sub _changed {
    my ( $self, $aspect ) = @_;
    $self->{listener}->add_event("changed:$aspect");
}

sub _fatal {
    my ( $self, $message ) = @_;
    $self->{listener}->add_event("fatal:$message");
}

sub _info {
    my ( $self, $message ) = @_;
    $self->{listener}->add_event("info:$message");
}

sub _strategy_for {
    my ( $self, $profile ) = @_;
    BitBack::Archiver::IndividualCompressedFiles->new($profile);
}

sub _warn {
    my ( $self, $message ) = @_;
    $self->{listener}->add_event("warn:$message");
}


