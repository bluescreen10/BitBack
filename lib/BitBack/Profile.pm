package BitBack::Profile;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = bless {
        name         => '',
        status       => '',
        last_run     => undef,
        last_success => undef,
        comparator   => undef,
        source       => undef,
        destination  => undef
    }, $class;
    return $self;
}


sub comparator {
    my $self = shift;
    if (@_) {
        $self->{comparator} = shift;
    }
    return $self->{comparator};
}

sub destination {
    my $self = shift;
    if (@_) {
        $self->{destination} = shift;
    }
    return $self->{destination};
}

sub name {
    my $self = shift;
    if (@_) {
        $self->{name} = shift;
    }
    return $self->{name};
}

sub last_run {
    my $self = shift;
    if (@_) {
        $self->{last_run} = shift;
    }
    return $self->{last_run};
}

sub last_success {
    my $self = shift;
    if (@_) {
        $self->{last_success} = shift;
    }
    return $self->{last_success};
}

sub source {
    my $self = shift;
    if (@_) {
        $self->{source} = shift;
    }
    return $self->{source};
}

sub status {
    my $self = shift;
    if (@_) {
        $self->{status} = shift;
    }
    return $self->{status};
}

1;
