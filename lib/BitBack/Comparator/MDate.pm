
package BitBack::Comparator::MDate;

use strict;
use warnings;
use base qw(BitBack::Comparator);

sub _files_differ {
    my ( $class, $file1, $file2 ) = @_;

    unless ( -e $file2 and -e $file1 ) {
        return 1;
    }

    return not((stat($file1))[9] == (stat($file2))[9]);
}

1;
