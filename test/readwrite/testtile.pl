#!perl

use strict;
use warnings;

use lib '../../lib';

use Civ4MapCad::Map::Tile;
my $tile = Civ4MapCad::Map::Tile->new();

my $filename = 'testTile.CivBeyondSwordWBSave';

open (my $fhi, $filename) or die $!;
my $beginTile = <$fhi>;
$tile->parse($fhi);
close $fhi;

use Data::Dumper;
print Dumper $tile;

open (my $fho, '>', "$filename.out") or die $!;
$tile->write($fho);
close $fho;