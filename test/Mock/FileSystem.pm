package Mock::FileSystem;

use strict;
use warnings;
use File::Spec;
use POSIX qw(ceil);
use constant BLKSIZE => 4096;

my $FileSystem = { type => 'd', contents => {} };

my %Modules;

# Override core functions
*CORE::GLOBAL::open = sub (*;$@) {
    my $package = ( caller() )[0];
    unless ( $Modules{$package} ) {
        return CORE::open( $_[0], $_[1], @_[ 2 .. $#_ ] );
    }
    return _open( $_[0], $_[1], @_[ 2 .. $#_ ] );
};

*CORE::GLOBAL::stat = sub {
    my $package = ( caller() )[0];
    unless ( $Modules{$package} ) {
        return CORE::stat(@_);
    }
    return _stat(@_);
};

*CORE::GLOBAL::binmode = sub {
    my $package = ( caller() )[0];
    unless ( $Modules{$package} ) {
        return CORE::binmode( $_[0] );
    }
    return _binmode(@_);
};

sub import {
    my ( $class, @modules ) = @_;

    my $package = caller;

    _export_functions_to($package);

    unless (@modules) {
        push @modules, $package;
    }

    foreach (@modules) {
        $Modules{$_} = 1;
    }
}

=head2 mock_file

mock_file(
   path     => "/tmp/something",
   content  => "Some content",
   mode     => "644",
   atime    =>
   error_on_open   => 1,
   error_on_unlick => 1,
   error_on_write  => 1,
   error_on_read   => 0,
);
=cut

sub mock_file {
    my %args = @_;

    $args{type} = 'f';

    my ( $volume, $dirs, $name ) = File::Spec->splitpath( $args{path} );
    delete $args{path};

    my $path = File::Spec->catdir( $volume, $dirs );

    mock_dir(
        path => $path,
        mode => $args{mode}
    );

    $args{mode} = oct( $args{mode} || "777" ) | oct("0100000");
    my $dir = _getdir($path);
    $dir->{$name} = \%args;

}

sub mock_dir {
    my %args = @_;

    my @dirs = File::Spec->splitdir( $args{path} );

    $args{mode} ||= "777";

    my $obj = $FileSystem;

    foreach (@dirs) {
        unless ( $obj->{contents}->{$_} ) {
            my $new_dir = {
                type     => 'd',
                contents => {},
                mode     => oct( $args{mode} ) | oct("0040000")
            };

            # "." Entry
            $new_dir->{contents}->{'.'} = {
                type => 'l',
                ref  => $new_dir,
                mode => oct( $args{mode} ) | oct("0120000")
            };

            # ".." Entry
            $new_dir->{contents}->{'..'} = {
                type => 'l',
                ref  => $obj,
                mode => oct( $args{mode} ) | oct("0120000")
            };

            $obj->{contents}->{$_} = $new_dir;

        }

        if ( $obj->{contents}->{$_}->{type} ne 'd' ) {
            die "Incorrect type\n";
        }

        $obj = $obj->{contents}->{$_};
    }
}

sub _export_functions_to {
    my $package = shift;

    no strict 'refs';

    *{"$package\::mock_file"} = \&mock_file;
    *{"$package\::mock_dir"}  = \&mock_dir;

    use strict 'refs';

}

sub _getdir {
    my $path = shift;

    my @dirs = File::Spec->splitdir($path);
    my $obj  = $FileSystem;

    foreach (@dirs) {
        unless ( $obj->{contents}->{$_} and $obj->{contents}->{$_}->{type} eq 'd' ) {
            die "Directory doesn't exists";
        }
        $obj = $obj->{contents}->{$_};
    }

    return $obj;

}

sub _binmode { }

sub _close { }

sub _closedir { }

sub _mkdir { }

sub _open {

    my ( $fh, $access, $name ) = @_;

    $name ||= '';
    my $compound = "$access $name";

    if ( $compound =~ /\s*(<|>|>>|\+<|\+>|\+>>)?\s*(\S+)\s*/ ) {
        $access = $1 || '<';
        $name = $2;
    }
    else {
        die 'Unexpected open() parameters for file mocking';
    }

    my $entry = _getentry($name);

    if ( !defined $entry ) {
        $! = 2;
        return 0;
    }

    my $content = $entry->{content};
    return CORE::open( $$fh, $access, \$content );
}

sub _opendir { }

sub _readdir { }

sub _rmmdir { }

sub _stat($) {
    my $filename = shift;

    my $entry = _getentry($filename);

    if ($entry) {
        my $size = _calculate_size($entry);

        return (
            1,                 # dev id,
            1,                 # inode id
            $entry->{mode},    # mode
            0,                 # number of harlinks to file
            1,                 # uid
            1,                 # gid
            0,                 # rdev
            $size,             # size
            $entry->{atime} || time(),    # atime,
            $entry->{mtime} || time(),    # mtime,
            $entry->{ctime} || time(),    # ctime,
            BLKSIZE,                             # blksize
            ceil( $size / BLKSIZE ) * BLKSIZE    # number of bloks
        );
    }
}

sub _sysopen {
    die "_sysopen\n";
}

sub _unlink { }

sub _utime { }

sub _getentry {
    my $filename = shift;

    my ( $volume, $dirs, $name ) = File::Spec->splitpath($filename);

    my $dir = _getdir( File::Spec->catdir( $volume, $dirs ) );

    if ($name) {
        return $dir->{$name};
    }
    else {
        return $dir;
    }
}

sub _calculate_size {
    my $file = shift;

    my $size = 0;

    if( $file->{type} eq 'f' && $file->{content}) {
        $size = length($file->{content});
    }

    return $size;
}

1;
