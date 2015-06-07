#!perl

use strict;
use warnings;

use lib '../../lib';

use Civ4MapCad::Map::MapInfo;
my $map = Civ4MapCad::Map::MapInfo->new();

my $filename = 'testMap.CivBeyondSwordWBSave';

open (my $fhi, $filename) or die $!;
my $beginMap = <$fhi>;
$map->parse($fhi);
close $fhi;

use Data::Dumper;
print Dumper $map;

open (my $fho, '>', "$filename.out") or die $!;
$map->write($fho);
close $fho;