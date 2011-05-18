package BitBack::Profile;

use strict;
use warnings;
use threads;
use threads::shared;

sub new {
    my @directory_filters : shared;
    my @file_filters : shared;

    my %self : shared = (
        name              => '',
        compare_method    => 'mdate',
        directory_filters => \@directory_filters,
        file_filters      => \@file_filters,
        encrypt           => undef,
        cipher            => 'Rinjdael',
        compression       => undef,
        percentage        => 0,
        is_running        => 0,
    );
    bless \%self;
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

sub notify {
    my ( $self, $listener ) = @_;
    $self->{listener} = shared_clone($listener);
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

sub percentage {
    my $self = shift;
    if (@_) {
        $self->{percentage} = shift;
        $self->_changed('percentage');
    }
    return $self->{percentage};
}

sub update_last_run {
    my $self = shift;
    $self->{last_run} = $self->_timestamp;
}

sub update_last_success {
    my $self = shift;
    $self->{last_success} = $self->_timestamp;
}

sub is_running {
    my $self = shift;
    if (@_) {
        $self->{is_running} = shift;
        $self->_changed('percentage');
    }
    return $self->{is_running};
}

sub _changed {
    my ( $self, $aspect ) = @_;
    if ( $self->{listener} ) {
        $self->{listener}->changed($aspect);
    }
}

sub _timestamp {
    my ( $sec, $min, $hour, $day, $month, $year ) = localtime();
    sprintf(
        "%04d-%02d-%02d %02d:%02d:%02d",
        $year + 1900,
        $month + 1, $day, $hour, $min, $sec
    );
}

1;
