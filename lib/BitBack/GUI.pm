package BitBack::GUI;

use strict;
use warnings;
use threads;
use threads::shared;
use Carp qw(confess);

my @events : shared;

sub new {
    my ( $class, $model ) = @_;

    my $self = bless { model => $model }, $class;
    $self->_init();
    return $self;
}

sub _init {
    my $self = shift;
    $self->{model}->notify($self);
}

sub changed {
    confess "To be implemented by the subclass";
}

sub fatal {
    confess "To be implemented by the subclass";
}

sub info {
    confess "To be implemented by the subclass";
}

sub start {
    my $self = shift;
    $self->{model}->read_config;
}

sub warn {
    die "To be implemented by the subclass";
}

sub process_events {
    my $self = shift;
    while ( scalar(@events) ) {
        my $event = shift(@events);
        if ( $event =~ /^(\w+):(.*)$/ ) {
            $self->$1($2);
        } else {
            $self->fatal("Invalid event: $event");
        }
    }
}

sub add_event {
    my ($self, $event) = @_;
    push @events, $event;
}

1;
