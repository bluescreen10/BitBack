package BitBack;

use strict;
use warnings;
use version;
use BitBack::ProfilesManager;
use Time::HiRes qw(usleep);
use BitBack::Archiver::IndividualCompressedFiles;

our $VERSION = qv(1.00);

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

sub initialize {
    my $self = shift;

    $self->{profiles_manager}->notify($self);

    eval { $self->{profiles_manager}->read_config; };

    if ($@) {
        $self->_fatal($@);
    }

}

sub archive {
    my ( $self, $name ) = @_;

    my $profile = $self->{profiles_manager}->profile_named($name);

    unless ($profile) {
        $self->_fatal("Profile \"$name\" does not exists");
    }

    $self->_info("Archiving \"$name\"");

    my $strategy = $self->_strategy_for($profile);
    $strategy->archive;

    foreach( @{$strategy->errors} ) {
        $self->_warn($_);
    }

    $self->_info('Finished');

}

sub notify {
    my ( $self, $target ) = @_;
    $self->{listener} = $target;
}

sub profiles {
    my $self = shift;

    $self->{profiles_manager}->profiles;
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

    foreach( @{$strategy->errors} ) {
        $self->_warn($_);
    }

    $self->_info('Finished');

}

sub _init {
    my ( $self, $options ) = @_;

    $self->{options}          = $options;
    $self->{listener}         = [];
    $self->{profiles_manager} = BitBack::ProfilesManager->new( $options->{config} );
    $self->{percentage}       = 0;
    $self->{running}          = 0;
}

sub _changed {
    my ( $self, $aspect ) = @_;
    $self->{listener}->changed($aspect);
}

sub _fatal {
    my ( $self, $message ) = @_;
    $self->{listener}->fatal($message);
}

sub _info {
    my ( $self, $message ) = @_;
    $self->{listener}->info($message);
}

sub _strategy_for {
    my ( $self, $profile ) = @_;
    BitBack::Archiver::IndividualCompressedFiles->new($profile);
}

sub _warn {
    my ( $self, $message ) = @_;
    $self->{listener}->warn($message);
}

# sub _timestamp {
#     my @lt = localtime();
#     $lt[5] += 1900;
#     $lt[4]++;
#     return
#       sprintf( "%04d-%02d-%02d %02d:%02d:%02d", $lt[5], $lt[4], $lt[3], $lt[2], $lt[1], $lt[0] );
# }


# sub _run {
#     my ( $self, $profile, $dry_run ) = @_;

#     #TODO: pre-actions in case single file compression

#     $self->percentage(0);

#     my $failures = [];

#     unless ( -d $profile->source ) {
#         $self->_fatal("Soruce directory $profile->{source} doesn't exists");
#         return;
#     }

#     my @changeset =
#       $profile->comparator->find_changes( $profile->source, $profile->destination, $failures );

#     my $archiver =
#       BitBack::Archiver::IndividualCompressedFiles->new( $profile->source, $profile->destination );

#     my $count       = 0;
#     my $total_count = scalar(@changeset);
#     my $last_update = time();

#     foreach my $step (@changeset) {
#         $archiver->process_step( $step, $failures );

#         # Update view;
#         $count++;
#         if ( time() - $last_update > 2 ) {
#             $last_update = time();
#             $self->percentage( $count / $total_count );
#         }
#     }

#     $self->percentage(1);

#     foreach (@$failures) {
#         $self->_warn($_);
#     }

#     unless (@$failures) {
#         $profile->last_success( $self->_timestamp );
#     }

# }

