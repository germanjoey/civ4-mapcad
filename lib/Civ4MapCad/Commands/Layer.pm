package Civ4MapCad::Commands::Layer;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(move_layer set_layer_priority cut_layer crop_layer extract_layer find_difference);

use Civ4MapCad::ParamParser;
use Civ4MapCad::Object::Layer;

my $recenter_help_text = qq[
    The specified layer's offset is set back to 0,0 within its group.
];
sub recenter {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer'],
        'help_text' => $recenter_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($layer, $offsetX, $offsetY) = $pparams->required();
    $layer->recenter();
    return 1;
}

my $move_layer_help_text = qq[
    The specified layer is moved by offsetX, offsetY within its group.
];
sub move_layer {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer', 'int', 'int'],
        'help_text' => $move_layer_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($layer, $offsetX, $offsetY) = $pparams->required();
    $layer->move($offsetX, $offsetY);
    return 1;
}

my $set_layer_priority_help_text = qq[
    The specified layer's priority is set to the specified value; 0 is the highest priority. Layers with equal or lower priority will be moved down.
];
sub set_layer_priority {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer', 'int'],
        'help_text' => $set_layer_priority_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($layer, $priority) = $pparams->required();
    my $group = $layer->get_group();
    
    $group->set_priority($layer->get_name(), $priority);
    
    return 1;
}

# apply a mask to a layer, delete everything outside of it, then resize the layer


my $crop_layer_priority_help_text = qq[
    The specified layer's priority is set to the specified value; 0 is the highest priority. Layers with equal or lower priority will be moved down.
];
sub crop_layer {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer', 'mask', 'int', 'int'],
        'help_text' => $crop_layer_priority_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($layer, $mask, $mask_offsetX, $mask_offsetY) = $pparams->get_required();
    
    die "crop_layer command not yet implemented\n\n";
    return 1;
}
