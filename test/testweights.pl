#!perl

use strict;
use warnings;

use lib '../lib';

use Data::Dumper;
use Civ4MapCad::Commands::Weight qw(load_terrain new_weight_table import_weight_table_from_file);;

my $state = {
    'current_line' => 'blah',
    'weight' => {},
    'terrain' => {},
};
load_terrain($state, '--filename', '../def/base_terrain.cfg');

import_weight_table_from_file($state, '--filename', 'testweights1.weight', '=>', '%forests');
import_weight_table_from_file($state, '--filename', 'testweights2.weight', '=>', '%all');

print Dumper $state->{'weight'}{'%forests'};
print Dumper $state->{'weight'}{'%all'};