#!perl

use strict;
use warnings;

use Getopt::Long qw(GetOptionsFromArray :config pass_through);

my $data   = "file.dat";
my $length = 24;
my $verbose;

my %results = (
    'file' => 'file.dat',
    'length' => 3,
    'verbose' => 0
);
my $cmd = '--file filex.dat --length 24 --verbose --blah';
my @params = split ' ', $cmd;

GetOptionsFromArray (\@params, \%results,  "file=s", "length=i", "verbose");

use Data::Dumper;
print Dumper \%results;
print Dumper \@params;
