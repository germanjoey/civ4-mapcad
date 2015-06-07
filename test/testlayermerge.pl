#!perl

use strict;
use warnings;

use lib '../lib';

use Civ4MapCad::Layer;
my $layer1 = Civ4MapCad::Layer->new_default(10, 10);
my $layer2 = Civ4MapCad::Layer->new_default(10, 10);

$layer1->fill_tile(1,1);
$layer2->fill_tile(1,1);
$layer2->move(3,3);

my $layer3 = $layer1->merge_with($layer2);

$layer1->{'map'}->export_map("testLayer1.CivBeyondSwordWBSave");
$layer2->{'map'}->export_map("testLayer2.CivBeyondSwordWBSave");
$layer3->{'map'}->export_map("testLayer3.CivBeyondSwordWBSave");
