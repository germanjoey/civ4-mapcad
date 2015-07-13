package Civ4MapCad::Commands::Layer;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(move_layer set_layer_priority cut_layer crop_layer extract_layer find_difference
                    flip_layer_tb flip_layer_lr copy_layer_from_group merge_two_layers expand_layer_canvas
                    increase_layer_priority decrease_layer_priority
                   );

use Civ4MapCad::ParamParser;
use Civ4MapCad::Util qw(deepcopy);

my $merge_two_layers_help_text = qq[
    Merges two layers based on their order when calling this command, rather than based on priority in the group (like with the 'flatten_group' command). The first layer wll be considered on top and be the remaining layer after flattening, while the second layer is considered the "background." Both layers must be members of the same group.
];
sub merge_two_layers {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer', 'layer'],
        'required_descriptions' => ['top layer', 'bottom layer'],
        'help_text' => $merge_two_layers_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($layer_top, $layer_bottom) = $pparams->get_required();
    
    if ($layer_top->get_group()->get_name() ne $layer_bottom->get_group()->get_name()) {
        $state->report_error("Both layers must be members of the same group.");
        return -1;
    }
    
    $layer_top->get_group()->merge_two_and_replace($layer_top->get_name(), $layer_bottom->get_name());;
    return 1;
}

my $expand_layer_canvas_help_text = qq[
    Expands a layer's dimensions; attempting to expand the layer to be bigger than its containing group will cause an error.
];
sub expand_layer_canvas {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer', 'int', 'int'],
        'required_descriptions' => ['layer to expand', 'expand width by', 'expand height by'],
        'help_text' => $expand_layer_canvas_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($layer, $by_width, $by_height) = $pparams->get_required();
    
    my $width = $layer->get_width();
    my $height = $layer->get_height();
    
    $layer->expand_dim($width + $by_width, $height + $by_height);
    return 1;
}

my $recenter_help_text = qq[
    The specified layer's offset is set back to 0,0 within its group.
];
sub recenter {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer'],
        'required_descriptions' => ['layer to move'],
        'help_text' => $recenter_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($layer, $offsetX, $offsetY) = $pparams->get_required();
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
        'required_descriptions' => ['layer to move', 'x coordinate', 'y coordinate'],
        'help_text' => $move_layer_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($layer, $offsetX, $offsetY) = $pparams->get_required();
    $layer->move($offsetX, $offsetY);
    return 1;
}

my $set_layer_priority_help_text = qq[
    The specified layer's priority is set to the specified value; the higher the number, the higher the priority. Higher priority layers are considered "above" those with lower priorities. When priority is set, the number will be adjusted so that there are no "gaps" in the priority list, and layers with equal or lower priority will be moved down.
];
sub set_layer_priority {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer', 'int'],
        'required_descriptions' => ['layer to set', 'priority'],
        'help_text' => $set_layer_priority_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($layer, $priority) = $pparams->get_required();
    my $group = $layer->get_group();
    
    my $max = $group->{'max_priority'};
    $priority = $max if $priority > $max;
    $priority = 0 if $priority < 0;
    
    # priorities are actually stored so that 0 is the highest, so we need to adjust
    $group->set_layer_priority($layer->get_name(), $max-$priority-1);
    
    return 1;
}

my $increase_layer_priority_help_text = qq[
    Moves a layer 'up' in the visibility stack; see 'set_layer_priority' for more details.
];
sub increase_layer_priority {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer'],
        'required_descriptions' => ['layer to set'],
        'help_text' => $increase_layer_priority_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($layer) = $pparams->get_required();
    my $group = $layer->get_group();
    
    $group->increase_priority($layer->get_name());
    return 1;
}

my $decrease_layer_priority_help_text = qq[
    Moves a layer 'down' in the visibility stack; see 'set_layer_priority' for more details.
];
sub decrease_layer_priority {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer'],
        'required_descriptions' => ['layer to set'],
        'help_text' => $decrease_layer_priority_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($layer) = $pparams->get_required();
    my $group = $layer->get_group();
    
    $group->decrease_priority($layer->get_name());
    return 1;
}

# apply a mask to a layer, delete everything outside of it, then resize the layer
my $crop_layer_help_text = qq[
    This layer's dimensions are trimmed to left/bottom/right/top, from the nominal dimensions of 0 / 0 / width-1 / height-1.
];
sub crop_layer {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer', 'int', 'int', 'int', 'int'],
        'required_descriptions' => ['layer to crop', 'left', 'bottom', 'right', 'top'],
        'help_text' => $crop_layer_help_text,
        'has_result' => 'layer',
        'allow_implied_result' => 1
    });
    return -1 if $pparams->has_error;
    
    my ($layer, $left, $bottom, $right, $top) = $pparams->get_required();
    
    my $width = $layer->get_width();
    my $height = $layer->get_height();
    
    my $x_ok = (($left >= 0) and ($right > $left) and ($right < $width));
    my $y_ok = (($bottom >= 0) and ($top > $bottom) and ($bottom < $height));
    
    unless ($x_ok and $y_ok) {
        $state->report_error("Dimensions are either out of bounds or crossed.");
        return -1;
    }
    
    my $copy = deepcopy($layer);
    $copy->crop($left, $bottom, $right, $top);
    
    my ($result_name) = $pparams->get_result_name();
    $state->set_variable($result_name, 'layer', $copy);
        
    return 1;
}

my $flip_layer_lr_help_text = qq[
    Flip a layer horizontally.
];
sub flip_layer_lr {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer'],
        'required_descriptions' => ['layer to flip'],
        'help_text' => $flip_layer_lr_help_text,
        'has_result' => 'layer',
        'allow_implied_result' => 1
    });
    return -1 if $pparams->has_error;
    
    my ($layer) = $pparams->get_required();
    my $copy = deepcopy($layer);
    $copy->fliplr();
    
    my ($result_name) = $pparams->get_result_name();
    $state->set_variable($result_name, 'layer', $copy);
    
    return 1;
}

my $flip_layer_tb_help_text = qq[
    Flip a layer horizontally.
];
sub flip_layer_tb {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer'],
        'required_descriptions' => ['layer to flip'],
        'help_text' => $flip_layer_tb_help_text,
        'has_result' => 'layer',
        'allow_implied_result' => 1
    });
    return -1 if $pparams->has_error;
    
    my ($layer) = $pparams->get_required();
    my $copy = deepcopy($layer);
    $copy->fliptb();
    
    my ($result_name) = $pparams->get_result_name();
    $state->set_variable($result_name, 'layer', $copy);
    
    return 1;
}

my $copy_layer_from_group_help_text = qq[
    Copy a layer from one group to another (or the same) group. If a new name is not specified, the same name is used.
];
sub copy_layer_from_group {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer'],
        'required_descriptions' => ['layer to copy'],
        'has_result' => 'layer',
        'help_text' => $copy_layer_from_group_help_text
    });
    return -1 if $pparams->has_error;
    
    my $result_name = $pparams->get_result_name();
    my ($layer) = $pparams->get_required();
    my $copy = deepcopy($layer);
    $state->set_variable($result_name, 'layer', $copy);
    
    return 1;
}

sub _assign_layer_result {
    my ($state, $result_name, $result_layer) = @_;
    
    my ($result_group_name, $result_layer_name) = $result_name =~ /\$(\w+)\.(\w+)/;
    my $group = $state->get_variable('$' . $result_group_name, 'group');
    $result_layer->rename($result_layer_name);
        
    if ($group->layer_exists($result_layer_name)) {
        $group->set_layer($result_layer_name, $result_layer);
    }
    else {
        my $result = $group->add_layer($result_layer);
        if (exists $result->{'error'}) {
            $state->report_warning($result->{'error_msg'});
        }
    }
    
    $result_layer->set_membership($group);
    $state->set_variable('$' . $result_name, 'layer', $result_layer);
}

1;