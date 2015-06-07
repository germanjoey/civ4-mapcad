#!perl

use strict;
use warnings;

use lib '../../lib';

use Civ4MapCad::Map;
my $map = Civ4MapCad::Map->new();

my $filename = 'test.CivBeyondSwordWBSave';
$map->import_map($filename);
$map->export_map("$filename.out");