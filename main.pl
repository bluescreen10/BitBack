#! /usr/bin/perl

use strict;
use warnings;
use XML::Simple;
use Data::Dumper;
use File::Path qw( make_path );
use IO::Compress::Gzip qw(gzip);
use GnuPG qw( :algo );

my $debug_level    = 0;
my $file_separator = '/';

sub main {

    my $options = parse_options( \@ARGV );
    my $config  = parse_config( $options->{config} );

    _DEBUG( Dumper($config), 10 );

    unless ($config
        and $config->{profiles}
        and $config->{profiles}->{profile}
        and $config->{profiles}->{profile}->{ $options->{profile} } )
    {
        _FATAL("Profile $options->{profile} is not defined in the config");
    }

    my $profile = $config->{profiles}->{profile}->{ $options->{profile} };

    _DEBUG( Dumper($profile), 5 );

    run($profile);
    exit(0);
}

sub run {
    my $profile = shift;

    #TODO: verify_profile($profile);

    my @failures;

    unless ( -d $profile->{source} ) {
        _FATAL("Soruce directory $profile->{source} doesn't exists");
    }

    make_path( $profile->{destination}, { error => \my $err } );
    if(@$err) {
        _FATAL("Can't create destination directory $profile->{destination}");
    }


    run_dir( '' , $profile, \@failures );

    foreach (@failures) {
        _WARN($_);
    }

}

sub run_dir {
    my ( $relative_folder, $profile, $failures ) = @_;

    my $base_folder = $profile->{source} . $relative_folder;

    _DEBUG( "Processing folder $base_folder", 10 );

    my $dh;
    unless ( opendir( $dh, $base_folder ) ) {
        push( @$failures, "Can't open dir $base_folder" );
        return;
    }

    while (my $each = readdir($dh)) {

        # Skip . and ..
        next if ( $each =~ /^\.{1,2}$/ );

        my $entry          = $base_folder . $file_separator . $each;
        my $relative_entry = $relative_folder . $file_separator . $each;
        my $destination    = $profile->{destination} . $file_separator . $relative_entry;

        # Directories
        if ( -d $entry ) {
            _DEBUG("Creating path $destination",10);
            make_path($destination, { error => \my $err } );
            if (@$err) {
                push(@$failures,"Can't create directory $destination");
            } else {
                run_dir( $relative_entry, $profile, $failures );
            }
        }

        # Files
        elsif ( -f $entry ) {
            run_file( $relative_entry, $profile, $failures );
        }

        # TODO: symlinks

    }

    closedir($dh);
}

sub run_file {
    my ( $relative_path, $profile, $failures ) = @_;

    # TODO: no compression option
    # TODO: no encryption option

    my $source      = $profile->{source} . $relative_path;
    my $destination = $profile->{destination} . $relative_path;

    _DEBUG( "Processing file $source", 10 );

    # TODO: handle other types of detection
    return if ( -x $destination and  ( stat($source) )[9] == ( stat($destination) )[9] );

    unless ( gzip $source => $destination ) {
        push( @$failures, "Can't process $source" );
        return;
    }

    # TODO: encryption
    # my $cipher = new GnuPG();

    # $cipher->encrypt(
    #     plaintext  => $destination,
    #     output     => $destination,
    #     symmetric  => 1,
    #     passphrase => $profile->{encryption}->{password}
    # );

    # Set mtime
    unless ( utime((stat($source))[8], (stat($source))[9], $destination) ) {
        push ( @$failures, "Can't set mtime in $destination" );
        return;
    }

}

sub parse_config {
    my $config_file = shift;

    unless ( -r $config_file ) {
        _FATAL("Can't open file $config_file");
    }

    return XMLin( $config_file, ForceArray => ['profile'] );
}

sub parse_options {
    my $source = shift;
    my $options = { config => 'config.xml', };

    for ( my $count = 0 ; $count < scalar @$source ; $count++ ) {
        my $param = @$source[$count];

        #Config
        if ( $param eq "--config" ) {
            $options->{config} = @$source[ ++$count ];
        }

        #Debug
        elsif ( $param eq "--debug" ) {
            $debug_level = int( @$source[ ++$count ] );
        }

        # Profile
        elsif ( $param eq "--profile" ) {
            $options->{profile} = @$source[ ++$count ];
        }
    }

    return $options;
}

# - Private ---------------------------------------------------------------------

sub _DEBUG {
    my ( $message, $level ) = @_;
    print "DEBUG: $message\n" if ( $debug_level >= $level );
}

sub _FATAL {
    print STDERR 'FATAL:' . shift() . "\n";
    exit 1;
}

sub _WARN {
    my $message = shift;
    print STDERR "WARNING: $_\n";
}

main(@ARGV);
