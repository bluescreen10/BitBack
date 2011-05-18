
package BitBack::ProfilesManager;

use strict;
use warnings;
use BitBack::Profile;
use XML::Simple qw(:strict);

sub new {
    my ( $class, $config ) = @_;
    bless { config => $config, profiles => [] }, $class;
}

sub changed {
    my ( $self, $aspect ) = @_;
    $self->_changed($aspect);
}

sub notify {
    my ( $self, $target ) = @_;
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

    my $config = XMLin(
        $self->{config},
        KeepRoot      => 1,
        KeyAttr       => 'profiles',
        ForceArray    => ['profile'],
        SuppressEmpty => 1,
    );
    use Data::Dumper;
    print Data::Dumper::Dumper($config);
    if ( $config and $config->{profiles}->{profile} ) {
        foreach my $data ( @{ $config->{profiles}->{profile} } ) {
            my $profile = BitBack::Profile->new;

            $profile->notify($self);
            $profile->name( $data->{name} );
            $profile->source( $data->{source} );
            $profile->destination( $data->{destination} );
            $profile->last_run( $data->{stats}->{lastRun} );
            $profile->last_success( $data->{stats}->{lastSuccess} );
            $profile->comparator( $data->{compareMethod} );

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
            fileChangeDetection => ['mdate']
        };
        push( @{ $xml->{profile} }, $data );

    }
    use Data::Dumper;
    XMLout( $xml, rootname => 'profiles', OutputFile => $self->{config} );
}

sub _changed {
    my ( $self, $aspect ) = @_;
    $self->{listener}->changed($aspect);
}

1;
