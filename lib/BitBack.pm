package BitBack;

use strict;
use warnings;
use version;
use BitBack::ProfilesManager;
use Time::HiRes qw(usleep);
use BitBack::Archiver::IndividualCompressedFiles;

our $VERSION = qv(1.00);

my $file_separator = '/';

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->_init(@_);
    return $self;
}

sub initialize {
    my $self = shift;

    eval { $self->{profiles_manager}->read_config; };

    if ($@) {
        $self->_fatal($@);
    }

    $self->_changed('profiles');
}

sub run {
    my ( $self, $name ) = @_;
    my $profile = $self->{profiles_manager}->profile_named($name);

    if ( $self->is_running ) {
        $self->_fatal('Already running a profile');
        return;
    }

    $self->is_running(1);
    $self->_info("Running profile $name");
    $profile->status('Running');
    $self->_changed('profiles');

    $self->_run($profile);

    $profile->status('');
    $profile->last_run($self->_timestamp);
    $self->{profiles_manager}->write_config;
    $self->_changed('profiles');
    $self->_info('Finished');
    $self->is_running(0);
}

sub _init {
    my ( $self, $options ) = @_;

    $self->{options}          = $options;
    $self->{listeners}        = [];
    $self->{profiles_manager} = BitBack::ProfilesManager->new( $options->{config} );
    $self->{percentage} = 0;
    $self->{running} = 0;
}

sub _run {
    my ( $self, $profile, $dry_run ) = @_;

    #TODO: pre-actions in case single file compression

    $self->percentage(0);

    my $failures = [];

    unless ( -d $profile->source ) {
        $self->_fatal("Soruce directory $profile->{source} doesn't exists");
        return;
    }

    my @changeset = $profile->comparator->find_changes( $profile->source, $profile->destination, $failures );

    my $archiver = BitBack::Archiver::IndividualCompressedFiles->new( $profile->source, $profile->destination);

    my $count = 0;
    my $total_count = scalar(@changeset);
    my $last_update = time();

    foreach my $step (@changeset) {
        $archiver->process_step($step, $failures);

        # Update view;
        $count++;
        if ( time() - $last_update > 2) {
            $last_update = time();
            $self->percentage($count/$total_count);
        }
    }

    $self->percentage(1);

    foreach (@$failures) {
        $self->_warn($_);
    }

    unless (@$failures) {
        $profile->last_success($self->_timestamp);
    }

}

sub notify {
    my ( $self, $target ) = @_;
    push( @{ $self->{listeners} }, $target );
}

sub profiles {
    my $self = shift;

    $self->{profiles_manager}->profiles;
}

sub percentage {
    my $self = shift;
    if (@_) {
        $self->{percentage} = shift;
        $self->_changed('percentage');
    }
    $self->{percentage};
}

sub is_running {
    my $self = shift;
    if (@_) {
        $self->{running} = shift;
        $self->_changed('is_running');
    }
    $self->{running};
}

sub _changed {
    my ( $self, $aspect ) = @_;

    foreach my $listener ( @{ $self->{listeners} } ) {
        $listener->changed($aspect);
    }

}

sub _fatal {
    my ( $self, $message ) = @_;
    foreach my $listener ( @{ $self->{listeners} } ) {
        $listener->fatal($message);
    }

}

sub _info {
    my ( $self, $message ) = @_;
    foreach my $listener ( @{ $self->{listeners} } ) {
        $listener->info($message);
    }

}

sub _warn {
    my ( $self, $message ) = @_;
    foreach my $listener ( @{ $self->{listeners} } ) {
        $listener->warn($message);
    }

}

sub _timestamp {
    my @lt = localtime();
    $lt[5] += 1900;
    $lt[4]++;
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d",$lt[5],$lt[4],$lt[3],$lt[2],$lt[1],$lt[0]);
}
