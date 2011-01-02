
package BitBack::Comparator;

use strict;
use warnings;

my $file_separator = '/';

sub _files_differ {
    return 1;
}

sub find_changes {
    my ( $class, $source_base, $destination_base, $failures ) = @_;

    my $changeset = [];

    $class->_find_changes_in( $source_base, $destination_base, '', $changeset, $failures );

    return @$changeset;

}

sub _find_changes_in {
    my ( $class, $source_base, $destination_base, $path, $changeset, $failures ) = @_;

    my $dir;

    unless ( opendir( $dir, "$source_base$file_separator$path" ) ) {
        push( @$failures, "Can't open directory $source_base$file_separator$path" );
        return;
    }

    unless (-e "$destination_base$file_separator$path"
        and -d "$destination_base$file_separator$path" )
    {

        # Remote directory doesn't exists
        push( @$changeset, { action => 'mkdir', path => $path } );
    }

    while ( my $entry = readdir($dir) ) {
        next if $entry =~ /^(\.|\..)$/;

        $entry = "$path$file_separator$entry";
        my $source      = "$source_base$file_separator$entry";
        my $destination = "$destination_base$file_separator$entry";

        if ( -d $source ) {
            $class->_find_changes_in( $source_base, $destination_base, $entry, $changeset, $failures );
        }

        elsif ( -f $source and $class->_files_differ( $source, $destination ) ) {
            push( @$changeset, { action => 'cpfile', path => $entry } );
        }

    }

    closedir($dir);

    # TODO: Scan remote folder for extra files

}

1;
