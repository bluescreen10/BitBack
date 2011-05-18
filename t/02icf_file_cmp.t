#!/usr/bin/perl

use strict;
use warnings;
use lib 'test';
use Mock::FileSystem qw(
  IO::File
  BitBack::Archiver::IndividualCompressedFiles
  IO::Uncompress::Unzip
);
use BitBack::Archiver::IndividualCompressedFiles;
use Test::Exception;
use Test::More tests => 14;

use constant {
    CONTENT        => "The quick brown fox jumped over the lazy dog\n",
    ZIPPED_CONTENT => pack( "H*",
            "504b03040a0000000000a0aa7f3e93a2a0be2d0000002d00000005001c0074"
          . "6d702f6155540900036c1a954d6c1a954d75780b000104e803000004e80300"
          . "0054686520717569636b2062726f776e20666f78206a756d706564206f7665"
          . "7220746865206c617a7920646f670a504b01021e030a0000000000a0aa7f3e"
          . "93a2a0be2d0000002d000000050018000000000001000000a4810000000074"
          . "6d702f6155540500036c1a954d75780b000104e803000004e8030000504b05"
          . "0600000000010001004b0000006c0000000000" ),
    ENCZIP_CONTENT => pack("H*", "00")
};

my $archiver = BitBack::Archiver::IndividualCompressedFiles->new;

mock_file(
    path    => "/tmp/src/a",
    content => CONTENT,
    mtime   => 1301075450,
);

mock_file(
    path    => "/tmp/dst/a.zip",
    content => ZIPPED_CONTENT,
    mtime   => 1301075455,
);

mock_file(
    path    => "/tmp/src/b",
    content => scalar reverse(CONTENT),
    mtime   => 1301075450,
);

mock_file(
    path    => "/tmp/dst/b.zip",
    content => ZIPPED_CONTENT,
    mtime   => 1301075450,
);

mock_file(
    path    => "/tmp/src/c",
    content => substr(CONTENT,-1),
    mtime   => 1301075450,
);

mock_file(
    path    => "/tmp/dst/c.zip",
    content => ZIPPED_CONTENT,
    mtime   => 1301075450,
);


#MDATE
my $actions = [];

lives_ok( sub { $archiver->_compare_files_mdate( "/tmp/src/b", "/tmp/dst/b.zip", $actions ) },
    'Identical files(MDATE)' );

is( scalar(@$actions), 0, 'Identical files(MDATE)' );

lives_ok( sub { $archiver->_compare_files_mdate( "/tmp/src/a", "/tmp/dst/a.zip", $actions ) },
    'Different files(MDATE)' );

is( scalar(@$actions), 1, 'Different files(MDATE)' );

#Content
$actions = [];

lives_ok( sub { $archiver->_compare_files_content( "/tmp/src/a", "/tmp/dst/a.zip", $actions ) },
    'Identical files(MD5)' );

is( scalar(@$actions), 0, 'Indentical files(MD5)');

lives_ok( sub { $archiver->_compare_files_content( "/tmp/src/b", "/tmp/dst/b.zip", $actions ) },
    'Different files(MD5)' );

is( scalar(@$actions), 1, 'Different files(MD5)');

#Size
$actions = [];

lives_ok( sub { $archiver->_compare_files_size( "/tmp/src/a", "/tmp/dst/a.zip", $actions ) },
    'Identical files(Size) #1' );

is( scalar(@$actions), 0, 'Indentical files(Size) #2');

lives_ok( sub { $archiver->_compare_files_size( "/tmp/src/b", "/tmp/dst/b.zip", $actions ) },
    'Identical files(Size) #2' );

is( scalar(@$actions), 0, 'Indentical files(Size) #2');

lives_ok( sub { $archiver->_compare_files_size( "/tmp/src/c", "/tmp/dst/c.zip", $actions ) },
    'Different files(Size)' );

is( scalar(@$actions), 1, 'Different files(Size)');
