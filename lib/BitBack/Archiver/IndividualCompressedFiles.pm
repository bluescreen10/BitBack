package BitBack::Archiver::IndividualCompressedFiles;

use strict;
use warnings;
use IO::Compress::Zip qw(zip $ZipError);
use IO::Uncompress::Unzip qw(unzip $UnzipError);
use File::Spec;
use Digest::MD5;
use IO::File;
use Crypt::CBC;

use constant { BUFFER_SIZE => 2**16 };

sub new {
    my $class = shift;
    my $self  = bless {
        profile        => shift,
        errors         => [],
        subfix         => '.zip',
        compare_method => 'md5',
        encrypt        => 0,
        password       => 'MyPassword1',
    }, $class;
    return $self;
}

sub archive {
    my ( $self, $dry_run ) = @_;

    $self->_initialize;
    my $actions = $self->_find_archive_actions;

    my $timestamp = time();
    my $counter   = 0;

    $self->{profile}->percentage(0);
    $self->{profile}->is_running(1);
    foreach (@$actions) {

        # Inform every 2 seconds the progress
        if ( time() - $timestamp > 2 ) {
            $timestamp = time();
            $self->{profile}->percentage( int( $counter / scalar(@$actions) * 100 ) );
        }

        # Create directory
        if ( $_->{action} eq 'mkpath' ) {
            unless ( mkdir $_->{entry} ) {
                push( @{ $self->{errors} }, $! );
            }
        }

        # Archive file
        elsif ( $_->{action} eq 'archive' ) {
            $self->_archive_file( $_->{source}, $_->{destination} );
        }

        $counter++;
    }

    $self->{profile}->update_last_run;
    $self->{profile}->update_last_success unless(scalar(@{$self->{errors}}));
    $self->{profile}->percentage(100);
    $self->{profile}->is_running(0);

}

sub errors {
    my $self = shift;
    return $self->{errors};
}

sub restore {

}

sub _archive_file {
    my ( $self, $src, $dst ) = @_;

    my ( undef, undef, $name ) = File::Spec->splitpath( $_->{source} );

    my $src_fh = IO::File->new( $src, 'r' );

    unless ($src_fh) {
        push( @{ $self->{errors} }, "Can't open file $src" );
        return;
    }

    my $dst_fh = IO::Compress::Zip->new( $dst, name => $name );

    unless ($dst_fh) {
        push( @{ $self->{errors} }, "Can't create file $dst" );
        return;
    }

    $src_fh->binmode;
    $dst_fh->binmode;

    my $cipher;
    if ( $self->{encrypt} ) {
        $cipher = Crypt::CBC->new( -key => $self->{password}, -cipher => 'Rijndael' );
        $cipher->start('encrypting');
    }

    my $buffer;
    while ( $src_fh->read( $buffer, BUFFER_SIZE ) ) {
        if ( $self->{encrypt} ) {
            $buffer = $cipher->crypt($buffer);
        }

        unless ( $dst_fh->write($buffer) ) {
            push( @{ $self->{errors} }, "Can't write into $dst" );
            $src_fh->close;
            $dst_fh->close;
            return;
        }
    }

    if ( $self->{encrypt} && $src_fh->tell ) {
        unless ( $dst_fh->write( $cipher->finish ) ) {
            push( @{ $self->{errors} }, "Can't write into $dst" );
            $src_fh->close;
            $dst_fh->close;
            return;
        }
    }

    $src_fh->close;
    $dst_fh->close;

    unless ( utime( ( stat($src) )[8], ( stat($src) )[9], $dst ) ) {
        push( @{ $self->{errors} }, "Can't set mtime in $dst" );
    }

}

sub _compare_files_mdate {
    my ( $self, $src_file, $dst_file, $actions ) = @_;

    if ( ( stat($src_file) )[9] != ( stat($dst_file) )[9] ) {
        push @$actions, { action => 'archive', source => $src_file, destination => $dst_file };
    }
}

sub _compare_files_content {
    my ( $self, $src_file, $dst_file, $actions ) = @_;

    my $hash = Digest::MD5->new;

    # Dst file
    my $cipher;
    if ( $self->{encrypt} ) {
        $cipher = Crypt::CBC->new( -key => $self->{password}, -cipher => 'Rijndael' );
        $cipher->start('decrypting');
    }

    my $fh = IO::Uncompress::Unzip->new($dst_file);
    $fh->binmode;

    my $buffer;
    while ( $fh->read( $buffer, BUFFER_SIZE ) ) {
        if ( $self->{encrypt} ) {
            $buffer = $cipher->crypt($buffer);
        }
        $hash->add($buffer);
    }

    if ( $self->{encrypt} ) {
        $hash->add( $cipher->finish() );
    }

    $fh->close;
    my $dst_digest = $hash->digest;

    # Source File
    $fh = IO::File->new( $src_file, 'r' );
    $fh->binmode($fh);
    $hash->addfile($fh);
    $fh->close;

    my $src_digest = $hash->digest;

    push @$actions, { action => 'archive', source => $src_file, destination => $dst_file }
      unless ( $src_digest eq $dst_digest );

}

sub _compare_files_size {
    my ( $self, $src_file, $dst_file, $actions ) = @_;

    my $dst_size = 0;

    my $cipher;
    if ( $self->{encrypt} ) {
        $cipher = Crypt::CBC->new( -key => $self->{password}, -cipher => 'Rijndael' );
        $cipher->start('decrypting');
    }

    my $fh = IO::Uncompress::Unzip->new($dst_file);
    $fh->binmode;

    my $buffer;
    while ( $fh->read( $buffer, BUFFER_SIZE ) ) {
        if ( $self->{encrypt} ) {
            $buffer = $cipher->crypt($buffer);
        }
        $dst_size += length($buffer);
    }

    if ( $self->{encrypt} ) {
        $dst_size += length( $cipher->finish() );
    }

    my $src_size = (stat($src_file))[7];

    push @$actions, { action => 'archive', source => $src_file, destination => $dst_file }
      unless ( $src_size eq $dst_size );

}

sub _compare_dir {
    my ( $self, $src, $dst, $relative_path, $actions ) = @_;

    my $src_dir = File::Spec->catdir( $src, $relative_path );
    my $dst_dir = File::Spec->catdir( $dst, $relative_path );

    my $dh;
    unless ( opendir( $dh, $src_dir ) ) {
        push @{ $self->{errors} }, "Can't open directory $src_dir";
        return;
    }

    unless ( $self->_is_directory($dst_dir) ) {
        push( @$actions, { action => 'mkpath', entry => $dst_dir } );
    }

    while ( my $entry = readdir($dh) ) {
        next if $entry =~ /^(\.|\..)$/;

        my $next_src = File::Spec->catfile( $src, $relative_path, $entry );

        if ( -f $next_src ) {
            my $src_file = $next_src;
            my $dst_file = File::Spec->catfile( $dst, $relative_path, $entry . $self->{subfix} );

            unless ( -f $dst_file ) {
                push @$actions,
                  { action => 'archive', source => $src_file, destination => $dst_file };
            }
            else {
                my $method = $self->{compare_file_method};
                eval { $self->$method( $src_file, $dst_file, $actions ); };
                if ($@) {
                    push @$actions,
                      { action => 'archive', source => $src_file, destination => $dst_file };
                }
            }
        }
        else {
            my $next_dir = File::Spec->abs2rel( $next_src, $src );
            $self->_compare_dir( $src, $dst, $next_dir, $actions );
        }
    }

    closedir($dh);

}

sub _find_archive_actions {
    my $self = shift;

    my $actions = [];
    $self->_compare_dir( $self->{profile}->source, $self->{profile}->destination, undef, $actions );
    return $actions;

}

sub _initialize {
    my $self = shift;

    my $method = lc( $self->{compare_method} );

    if ( $method eq 'md5' ) {
        $self->{compare_file_method} = '_compare_files_content';
    }

    elsif ( $method eq 'mdate' ) {
        $self->{compare_file_method} = '_compare_files_mdate';
    }

    else {
        die "Method $method not supported";
    }

}

sub _is_directory {
    -d $_[1];
}

sub _is_file {
    -f $_[1];
}

sub _is_existent {
    -e $_[1];
}

1;
