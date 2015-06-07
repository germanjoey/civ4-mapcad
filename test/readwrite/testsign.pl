#!perl

use strict;
use warnings;

use lib '../../lib';

use Civ4MapCad::Map::Sign;
my $sign = Civ4MapCad::Map::Sign->new();

my $filename = 'testSign.CivBeyondSwordWBSave';

open (my $fhi, $filename) or die $!;
my $beginSign = <$fhi>;
$sign->parse($fhi);
close $fhi;

use Data::Dumper;
print Dumper $sign;

open (my $fho, '>', "$filename.out") or die $!;
$sign->write($fho);
close $fho;