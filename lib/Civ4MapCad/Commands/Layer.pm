package Civ4MapCad::Commands::Layer;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(move_layer set_layer_priority cut_layer crop_layer extract_layer find_difference);

use Civ4MapCad::ParamParser;
use Civ4MapCad::Object::Layer;

sub recenter {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer']
    });
    return -1 if $pparams->error;
    
    my ($layer, $offsetX, $offsetY) = $pparams->required();
    $layer->recenter();
    return 1;
}

sub move_layer {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer', 'int', 'int']
    });
    return -1 if $pparams->error;
    
    my ($layer, $offsetX, $offsetY) = $pparams->required();
    $layer->move($offsetX, $offsetY);
    return 1;
}

sub set_layer_priority {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer', 'int']
    });
    return -1 if $pparams->error;
    
    my ($layer, $priority) = $pparams->required();
    my $group = $layer->get_group();
    
    $group->set_priority($layer->get_name(), $priority);
    
    return 1;
}

# apply a mask to a layer, cut it out, and add it as a new layer to the same project with +1 priority
sub cut_out_layer {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'shape_params' => 1,
        'has_result' => 'mask',
        'required' => ['shape'],
        'optional' => {
            'width' => 0,
            'height' => 0
        }
    });
    return -1 if $pparams->error;
    
    print "cut_layer command executed\n\n";
    return 1;
}

# apply a mask to a layer, delete everything outside of it, then resize the layer
sub crop_layer {
    my ($state, @params) = @_;
    print "crop_layer command executed\n\n";
    return 1;
}
