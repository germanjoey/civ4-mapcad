#!perl

use strict;
use warnings;

use lib '../lib';

use Data::Dumper;
use Civ4MapCad::Util qw(_process_params);

my $state = {
    'current_line' => '',
    'layer' => {
        'projectX.layername' => 'layervalue',
    },
    'group' => {
        'projectX' => 'projectvalue',
    },
    'mask' => {
        'maskname' => 'maskvalue'
    },
    'other' => {
        
    }
};

my $command = 'whatever $projectX.layername @maskname --flag1 => $projectX.meow';
$state->{'current_line'} = $command;
my @params = split (' ', $command); shift @params;
my $pparams = _process_params($state, \@params, {
    'has_result' => 'layer',
    'required' => ['layer', 'mask'],
    'optional' => {
        '-flag1' => 0,
        'flag2' => 0
    }
});

print Dumper $pparams;