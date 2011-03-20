package BitBack::GUI;

use strict;
use warnings;
use Carp qw(confess);

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
    $self->{model}->initialize;
}

sub warn {
    die "To be implemented by the subclass";
}

1;
