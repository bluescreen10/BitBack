
package BitBack::ProfilesManager;

use strict;
use warnings;
use BitBack::Profile;
use BitBack::Comparator::MDate;
use XML::Simple;

sub new {
    my ( $class, $config ) = @_;

    my $self = bless { config => $config, profiles => [] }, $class;
    return $self;
}

sub changed {
    my ($self,$aspect) = @_;
    $self->_changed($aspect);
}

sub notify {
    my ($self, $target ) = @_;
    $self->{listener} = $target;
}

sub profiles {
    my $self = shift;
    return $self->{profiles};
}

sub profile_named {
    my ( $self, $name ) = @_;

    foreach my $profile ( @{ $self->{profiles} } ) {
        return $profile if ( $profile->name eq $name );
    }

    return undef;
}

sub read_config {
    my $self = shift;

    # If no config file return
    return unless ( -e $self->{config} );

    my $config = XMLin( $self->{config}, ForceArray => ['profile'] );

    if ( $config and $config->{profile} ) {
        foreach my $data ( @{ $config->{profile} } ) {
            my $profile = BitBack::Profile->new;

            $profile->notify($self);
            $profile->name( $data->{profileName} );
            $profile->source( $data->{source} );
            $profile->destination( $data->{destination} );
            $profile->last_run( $data->{lastRun} );
            $profile->last_success( $data->{lastSuccess} );
            $profile->comparator( $data->{fileChangeDetection} );

            push( @{ $self->{profiles} }, $profile );
        }
    }
    $self->_changed('profiles');
}

sub write_config {
    my $self = shift;

    my $xml = { profile => [] };

    foreach my $profile ( @{ $self->{profiles} } ) {
        my $data = {
            profileName         => [ $profile->name ],
            source              => [ $profile->source ],
            destination         => [ $profile->destination ],
            lastSuccess         => [ $profile->last_success ],
            lastRun             => [ $profile->last_run ],
            fileChangeDetection => [ 'mdate' ]
        };
        push( @{ $xml->{profile} }, $data );

    }
    use Data::Dumper;
    XMLout($xml, rootname => 'profiles', OutputFile => $self->{config});
}

sub _changed {
    my ( $self, $aspect ) = @_;
    $self->{listener}->changed($aspect);
}

1;
