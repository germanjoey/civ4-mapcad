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
    return -1 if $pparams->has_error;
    
    my ($layer, $offsetX, $offsetY) = $pparams->required();
    $layer->recenter();
    return 1;
}

sub move_layer {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer', 'int', 'int']
    });
    return -1 if $pparams->has_error;
    
    my ($layer, $offsetX, $offsetY) = $pparams->required();
    $layer->move($offsetX, $offsetY);
    return 1;
}

sub set_layer_priority {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer', 'int']
    });
    return -1 if $pparams->has_error;
    
    my ($layer, $priority) = $pparams->required();
    my $group = $layer->get_group();
    
    $group->set_priority($layer->get_name(), $priority);
    
    return 1;
}

# apply a mask to a layer, delete everything outside of it, then resize the layer
sub crop_layer {
    my ($state, @params) = @_;
    die "crop_layer command not yet implemented\n\n";
    return 1;
}
