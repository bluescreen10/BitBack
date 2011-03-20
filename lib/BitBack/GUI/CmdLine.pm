package BitBack::GUI::CmdLine;

use strict;
use warnings;
use base qw(BitBack::GUI);

my @animation_steps = qw( | / - \ );

sub start {
    my ( $self, $profile ) = @_;

    $self->SUPER::start();

    $self->{animation_step} = 0;
    $self->{profile_name}   = $profile;
    $self->{model}->archive($profile);
}

sub changed {
    my ( $self, $aspect ) = @_;
    if ( $aspect eq 'percentage' ) {
        $self->_changed_percentage;
    }
}

sub info {
    my ( $self, $message ) = @_;
    print "$message\n";
}

sub warn {
    my ( $self, $message ) = @_;
    print STDERR "WARNING: $message\n";
}

sub _changed_percentage {
    my $self = shift;
    my $percentage;

    foreach ( @{ $self->{model}->profiles } ) {
        if ( $_->name eq $self->{profile_name} ) {
            $percentage = $_->percentage;
        }
    }

    #Flush buffer
    $|++;
    print "\r";

    if ( $percentage != 100 ) {
        $self->{animation_step}++;
        $self->{animation_step} %= scalar(@animation_steps);

        print sprintf( "%s %4.2d%%", $animation_steps[ $self->{animation_step}++ ], $percentage );
    }
}

