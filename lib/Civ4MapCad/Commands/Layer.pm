package Civ4MapCad::Commands::Layer;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(move_layer_to_location move_layer_by set_layer_priority crop_layer  
                    flip_layer_tb flip_layer_lr copy_layer_from_group merge_two_layers expand_layer_canvas
                    increase_layer_priority decrease_layer_priority set_tile rename_layer delete_layer rotate_layer
                    strip_all_units_from_layer
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
    return 1 if $pparams->done;
    
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
    return 1 if $pparams->done;
    
    my ($layer, $by_width, $by_height) = $pparams->get_required();
    
    my $new_width = $layer->get_width() + $by_width;
    my $new_height = $layer->get_height() + $by_height;
    
    my $group = $layer->get_group();
    if (($group->get_width() < $new_width) or ($group->get_height() < $new_height)) {
        $state->report_warning("new width/height of $new_width/$new_height exceeds dimensions of group \$" . $group->get_name() . " - expanding that as well.");
        $group->expand_dim($new_width, $new_height);
    }
    
    $layer->expand_dim($new_width, $new_height);
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
    return 1 if $pparams->done;
    
    my ($layer, $offsetX, $offsetY) = $pparams->get_required();
    $layer->recenter();
    return 1;
}

my $move_layer_to_location_help_text = qq[
    The specified layer is moved to location x,y within its group, referenced from the lower-right corner of the layer.
];
sub move_layer_to_location {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer', 'int', 'int'],
        'required_descriptions' => ['layer to move', 'layer\'s 0,0 will be moved to this x coordinate within its group', 'layer\'s 0,0 will be moved to this y coordinate within its group'],
        'help_text' => $move_layer_to_location_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($layer, $locationX, $locationY) = $pparams->get_required();
    $layer->move_to($locationX, $locationY);
    return 1;
}

my $move_layer_by_help_text = qq[
    The specified layer is moved by offsetX, offsetY within its group, referenced from the lower-right corner of the layer.
];
sub move_layer_by {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer', 'int', 'int'],
        'required_descriptions' => ['layer to move', 'move by this amount in the x direction', 'move by this amount in the y direction'],
        'help_text' => $move_layer_by_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($layer, $offsetX, $offsetY) = $pparams->get_required();
    $layer->move_by($offsetX, $offsetY);
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
    return 1 if $pparams->done;
    
    my ($layer, $priority) = $pparams->get_required();
    my $group = $layer->get_group();
    
    my $max = $group->{'max_priority'};
    $priority = ($max+2) if $priority > ($max+1);
    $priority = 0 if $priority < 0;
    
    # priorities are actually stored so that 0 is the highest, so we need to adjust
    $group->set_layer_priority($layer->get_name(), ($max+1)-$priority);
    
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
    return 1 if $pparams->done;
    
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
    return 1 if $pparams->done;
    
    my ($layer) = $pparams->get_required();
    my $group = $layer->get_group();
    
    $group->decrease_priority($layer->get_name());
    return 1;
}

# apply a mask to a layer, delete everything outside of it, then resize the layer
my $crop_layer_help_text = qq[
    This layer's dimensions are trimmed to left/bottom/right/top, from the nominal dimensions of 0 / 0 / width-1 / height-1, in reference to the layer. After the crop, the layer is then moved by -left, -bottom, so that tiles are essentially in the exact same place they started.
];
sub crop_layer {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'layer',
        'allow_implied_result' => 1,
        'required' => ['layer', 'int', 'int', 'int', 'int'],
        'required_descriptions' => ['layer to crop', 'left', 'bottom', 'right', 'top'],
        'help_text' => $crop_layer_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($layer, $left, $bottom, $right, $top) = $pparams->get_required();
    
    my $width = $layer->get_width();
    my $height = $layer->get_height();
    
    my $x_ok = (($left >= 0) and ($right > $left) and ($right < $width));
    my $y_ok = (($bottom >= 0) and ($top > $bottom) and ($bottom < $height));
    
    unless ($x_ok and $y_ok) {
        $state->report_error("Dimensions are either out of bounds or crossed.");
        return -1;
    }
    
    my ($result_name) = $pparams->get_result_name();
    my $copy = ($result_name eq $layer->get_full_name()) ? $layer : deepcopy($layer);
    
    $copy->crop($left, $bottom, $right, $top);
    $copy->move_by(-$left, -$bottom);
    $state->set_variable($result_name, 'layer', $copy);
        
    return 1;
}

my $flip_layer_lr_help_text = qq[
    Flip a layer horizontally. Rivers' direction in the layer are also flipped to match the new orientation.
];
sub flip_layer_lr {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'layer',
        'allow_implied_result' => 1,
        'required' => ['layer'],
        'required_descriptions' => ['layer to flip'],
        'help_text' => $flip_layer_lr_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($layer) = $pparams->get_required();
    my ($result_name) = $pparams->get_result_name();
    my $copy = ($result_name eq $layer->get_full_name()) ? $layer : deepcopy($layer);
    
    $copy->fliplr();
    $state->set_variable($result_name, 'layer', $copy);
    return 1;
}

my $flip_layer_tb_help_text = qq[
    Flip a layer horizontally. Rivers' direction in the layer are also flipped to match the new orientation.
];
sub flip_layer_tb {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'layer',
        'allow_implied_result' => 1,
        'required' => ['layer'],
        'required_descriptions' => ['layer to flip'],
        'help_text' => $flip_layer_tb_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($layer) = $pparams->get_required();
    my ($result_name) = $pparams->get_result_name();
    my $copy = ($result_name eq $layer->get_full_name()) ? $layer : deepcopy($layer);
    
    $copy->fliptb();
    $state->set_variable($result_name, 'layer', $copy);
    return 1;
}

my $copy_layer_from_group_help_text = qq[
    Copy a layer from one group to another (or the same) group. 
];
sub copy_layer_from_group {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer'],
        'required_descriptions' => ['layer to copy'],
        'has_result' => 'layer',
        'help_text' => $copy_layer_from_group_help_text,
        'optional' => {
            'place_on_top' => 'false'
        },
        'optional_descriptions' => {
            'place_on_top' => 'If set, then the copied layer is set to top priority in the new group.'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my $place_on_top = $pparams->get_named('place_on_top');
    my ($layer) = $pparams->get_required();
    my $copy = deepcopy($layer);
    
    $copy->move_to(0,0);
    $state->set_variable($result_name, 'layer', $copy);
    
    if ($place_on_top) {
        $copy->get_group()->set_layer_priority($copy->get_name(), -1);
    }
    
    return 1;
}

my $set_tile_help_text = qq[
    Sets a specific coordinate in a layer to a specific terrain value.
];
sub set_tile {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'help_text' => $set_tile_help_text,
        'required' => ['layer', 'int', 'int', 'terrain'],
        'required_descriptions' => ['the layer to modify', 'x coordinate', 'y coordinate', 'terrain name to set']
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($layer, $x, $y, $terrain) = $pparams->get_required();
    my $result_name = $pparams->get_result_name();
    
    if (($x >= $layer->get_width()) or ($y >= $layer->get_height())) {
        my $size = $layer->get_width() . ' x ' . $layer->get_height();
        my $name = $layer->get_name();
        $state->report_error("Coordinate value ($x,$y) is out of bounds of layer $name (size: $size)");
        return -1;
    }
    
    my $copy = deepcopy($layer);
    $layer->set_tile($x, $y, $terrain);
    return 1;
}


my $delete_layer_help_text = qq[
    Deletes a layer from a group.
];
sub delete_layer {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'help_text' => $delete_layer_help_text,
        'required' => ['layer'],
        'required_descriptions' => ['the layer to delete']
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($layer) = $pparams->get_required();
    $state->delete_variable($layer->get_full_name(), 'layer');
    
    return 1;
}

my $rename_layer_help_text = qq[
    Renames a layer, if you don't want to use copy_layer_from_group + delete_layer.
];
sub rename_layer {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'help_text' => $rename_layer_help_text,
        'required' => ['layer', 'str'],
        'required_descriptions' => ['the layer to rename', 'the short name of the layer; no "$" or group name needed']
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($layer, $new_name) = $pparams->get_required();
    my $group = $layer->get_group();
    my $old_layer_name = $layer->get_name();
    
    if ($new_name =~ /\W/) {
        $state->report_error("new layer name \"$new_name\" is illegal; please use only _ and alphanumeric characters");
        return -1;
    }
    
    my $p = $group->get_layer_priority($old_layer_name);
    $state->delete_variable($layer->get_full_name(), 'layer');
    $layer->rename_layer($new_name);
    $state->set_variable($layer->get_full_name(), 'layer', $layer);
    $group->set_layer_priority($new_name, $p);
    
    return 1;
}

my $rotate_layer_help_text = qq[
    This function rotate a layer around the origin point.
    Rotations of exacty 90/180/270 degrees will be exact, but rotations of
    arbitrary degrees will not be. There's two reasons for this. The first is
    because we'll have quantization error due to having a grid of tiles and
    only being able to move tiles by whole units. The second is because it is
    impossible to change the orientation of the tiles themselves. For example,
    lets say you have a wooden chess board in front of you, and you rotated it
    30 degrees. Look at the checkboard: each individual square is also rotated
    by 30 degrees. However, we can't do that here; all tiles are always perfect
    squares, perpendicular to the X and Y axis. This command tries its very
    best to rotate a layer according to any angle and will report the actual
    rotation angle if it fails to get an exact match.
    <BREAK>
    If the rotation result is poor, you can try specifying '--iteration' to be a 
    value greater than 1. In this case, the algorithm will attempt to rotate a
    pattern in small steps; e.g. if the rotation angle=39 and iterations=3, we'll
    do 3 rotations of 13 degrees. Rotating in small steps will give more accurate
    output angle but maybe jumble the result a bit more; again, some error is
    unavoidable due to the discrete nature of the problem.
    <BREAK>
    rotate_layer will scale the canvas and move the layer as appropriately so that
    the result will be an exact rotation once the layer's group is flattened. However,
    this will add a lot of empty space. You can stop this by using the '--autocrop' option. 
    This can be useful if, for example, you want to just to crop the rotated result
    afterwards anyways.
];

# TODO: allow arbitrary rotation origins by shifting the tiles before/after the rotation
sub rotate_layer {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'layer',
        'allow_implied_result' => 1,
        'required' => ['layer', 'float'],
        'required_descriptions' => ['the layer to rotate', 'the angle of rotation, in degrees'],
        'help_text' => $rotate_layer_help_text,
        'optional' => {
            'iterations' => 1,
            'autocrop' => 'false'
        },
        'optional_descriptions' => {
            'iterations' => 'Set to a higher value to rotate the object in this many small steps, which may give a different-looking result.',
            'autocrop' => 'Rather than massively expanding/moving the layer to fit the actual tile rotation (e.g. both width and height would be doubled for a rotation of 180 degrees), that step is skipped. Dead space, including water, is trimmed away from the edges of the object.'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $it = $pparams->get_named('iterations');
    my $autocrop = $pparams->get_named('autocrop');
    my ($layer, $angle) = $pparams->get_required();
    
    my ($result_name) = $pparams->get_result_name();
    my $copy = ($result_name eq $layer->get_full_name()) ? $layer : deepcopy($layer);
    
    my ($move_x, $move_y, $result_angle1, $result_angle2) = $copy->rotate($angle, $it, $autocrop);
    
    my $res = sprintf "%6.2f / %6.2f", $result_angle1, $result_angle2;
    $res =~ s/\s+/ /g;
    
    my @results = ("Results for rotation of " . $layer->get_full_name() . " by $angle degrees:",
                   "  After rotation, the layer was moved by $move_x, $move_y.",
                   "  Actual angle of rotation, as measured longways / sideways: $res.");
                   
    if ($autocrop) {
        $results[1] =~ s/was/would have been/;
    }
    
    $state->list( @results );
    $state->set_variable($result_name, 'layer', $copy);
    return 1;
}

my $strip_all_units_from_layer_help_text = qq[
    All units are removed from the map. This command modifies the layer.
];
sub strip_all_units_from_layer {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer'],
        'required_descriptions' => ['layer to strip from'],
        'help_text' => $strip_all_units_from_layer_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my ($layer) = $pparams->get_required();
    $layer->strip_all_units();
    
    return 1;
}

1;