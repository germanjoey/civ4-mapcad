package Civ4MapCad::Commands::Mask;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(import_mask_from_ascii new_mask_from_shape mask_difference mask_union mask_intersect 
                    mask_invert mask_threshold modify_layer_with_mask cutout_layer_with_mask apply_shape_to_mask  
                    generate_layer_from_mask new_mask_from_magic_wand export_mask_to_ascii set_mask_coord
                    export_mask_to_table import_mask_from_table mask_from_water mask_from_landmass
                    new_mask_from_polygon grow_mask shrink_mask count_mask_value);

use Math::Geometry::Planar qw(IsInsidePolygon IsSimplePolygon);

use Civ4MapCad::Util qw(deepcopy);
use Civ4MapCad::ParamParser;
use Civ4MapCad::Object::Mask;
use Civ4MapCad::Ascii qw(clean_ascii import_ascii_mapping_file);


my $new_mask_from_shape_help_text = qq[
    The 'new_mask_from_shape' command generates a mask by applying a shape function to a blank canvas of size width/height.
    (the two required integer paramaters). See the 'Shapes and Masks' section of the html documentation for more details.
];
sub new_mask_from_shape {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_shape_params' => 1,
        'has_result' => 'mask',
        'required' => ['shape', 'int', 'int'],
        'required_descriptions' => ['shape to generate mask with', 'width', 'height'],
        'help_text' => $new_mask_from_shape_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($shape, $width, $height) = $pparams->get_required();
    my $shape_params = $pparams->get_shape_params();
    
    $shape_params->{'width'} = $width;
    $shape_params->{'height'} = $height;
    
    if (($width == 0) or ($height == 0)) {
        $state->report_error("new mask dimensions must have non-zero width and height.");
        return -1;
    }
    
    my $result_name = $pparams->get_result_name();
    $state->set_variable($result_name, 'mask', Civ4MapCad::Object::Mask->new_from_shape($width, $height, $shape, $shape_params));
    
    return 1;
}

my $new_mask_from_polygon_help_text = qq[
    The 'new_mask_from_shape' command generates a mask by applying a shape function to a blank canvas of size width/height.
    (the two required integer paramaters). See the 'Shapes and Masks' section of the html documentation for more details.
];
sub new_mask_from_polygon {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'mask',
        'required' => ['int', 'int', '*str'],
        'required_descriptions' => ['width', 'height', 'coordinate, in the form "x,y"'],
        'help_text' => $new_mask_from_polygon_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my ($width, $height, @coords) = $pparams->get_required();
    
    my @points;
    foreach my $coord (@coords) {
        if ($coord !~ /^\s*\d+\s*,\s*\d+\s*$/) {
            $state->report_error(qq[coordinate "$coord" is not in proper form; must be "x,y".]);
            return -1;
        }
        
        $coord =~ s/\s//g;
        my ($x, $y) = split ',', $coord;
        push @points, [$x, $y];
    }
    
    if (3 > @points) {
        $state->report_error("A polygon must have at least three points! And don't forget to wrap back to start!");
        return -1;
    }
    
    my $simple = 0;
    eval {
        if (IsSimplePolygon(\@points)) {
            $simple = 1;
        }
    };
    if ($@) {
        $state->report_error("Unknown error in checking polygon validity: $@.");
        return -1;
    }
    if ($simple == 0) {
        $state->report_error("Polygon is not simple, meaning that it either is not closed or contains intersections.");
        return -1;
    }
    
    my $mask = Civ4MapCad::Object::Mask->new_blank($width, $height);
    eval {
        foreach my $x (0..($width-1)) {
            $mask->{'canvas'}[$x] = [];
            foreach my $y (0..($height-1)) {
                $mask->{'canvas'}[$x][$y] = (IsInsidePolygon(\@points, [$x, $y])) ? 1 : 0;
            }
        }
    };
    
    if ($@) {
        $state->report_error("Unknown error in constructing mask from polygon: $@.");
        return -1;
    }
    
    $state->set_variable($result_name, 'mask', $mask);
    return 1;
}

my $import_mask_from_ascii_help_text = qq[
    The 'import_mask_from_ascii' command generates a mask by reading in an ascii art shape and translating the characters
    into 1's and zeroes, if, for examples, you wanted to create a landmass that looked like some kind of defined shape. By
    default, a '*' equals a value of 1.0, while a ' ' equals a 0.0.
];
sub import_mask_from_ascii {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['str'],
        'has_result' => 'mask',
        'help_text' => $import_mask_from_ascii_help_text,
        'required_descriptions' => ['input filename'],
        'optional' => {
            'mapping_file' => 'def/standard_ascii.mapping'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($filename) = $pparams->get_required();
    my $ret = open (my $test, $filename) || 0;
    unless ($ret) {
        $state->report_error("cannot import ascii shape from '$filename': $!");
        return -1;
    }
    close $test;
    
    my $mapping_file = $pparams->get_named('mapping_file');
    my $mapping = import_ascii_mapping_file($mapping_file);
    if (exists $mapping->{'error'}) {
        $state->report_error($mapping->{'error_msg'});
        return -1;
    }
    
    my $result_name = $pparams->get_result_name();
    my $mask = Civ4MapCad::Object::Mask->new_from_ascii($filename, $mapping);
    if (exists $mask->{'error'}) {
        $state->report_error($mask->{'error_msg'});
        return -1;
    }
    
    $state->set_variable($result_name, 'mask', $mask);
    
    return 1;
}

my $import_mask_from_table_help_text = qq[
    Imports a mask from a table file; one line per coordinate, first column x, second column y, third column value.
];
sub import_mask_from_table {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['str'],
        'has_result' => 'mask',
        'required_descriptions' => ['input filename'],
        'help_text' => $import_mask_from_table_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($filename) = $pparams->get_required();
    my $ret = open (my $test, $filename) || 0;
    unless ($ret) {
        $state->report_error("cannot import mask from '$filename': $!");
        return -1;
    }
    close $test;
    
    my $result_name = $pparams->get_result_name();
    my $mask = Civ4MapCad::Object::Mask->new_from_file($filename);
    if (exists $mask->{'error'}) {
        $state->report_error($mask->{'error_msg'});
        return -1;
    }
    
    $state->set_variable($result_name, 'mask', $mask);
    
    return 1;
}

my $export_mask_to_table_help_text = qq[
    Exports the mask to a table file; one line per coordinate, first column x, second column y, third column value.
];
sub export_mask_to_table {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['mask', 'str'],
        'help_text' => $export_mask_to_table_help_text,
        'required_descriptions' => ['mask to export', 'output filename'],
        'optional' => {
            'mapping_file' => 'def/standard_ascii.mapping'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($mask, $filename) = $pparams->get_required();
    $mask->export_to_file($filename);
    
    return 1;
}

my $export_mask_to_ascii_help_text = qq[
    This command generates an ascii rendering of a mask based on a mapping file. The second parameter is the
    output filename. The format of the mapping file is that there's one character and one
    value per line. Values that don't exactly match will instead use the closest value instead. 
];
sub export_mask_to_ascii {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['mask', 'str'],
        'help_text' => $export_mask_to_ascii_help_text,
        'required_descriptions' => ['output filename'],
        'optional' => {
            'mapping_file' => 'def/standard_ascii.mapping'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($mask, $filename) = $pparams->get_required();
    
    my $mapping_file = $pparams->get_named('mapping_file');
    my $mapping = import_ascii_mapping_file($mapping_file);
    if (exists $mapping->{'error'}) {
        $state->report_error($mapping->{'error_msg'});
        return -1;
    }
    
    $mask->export_to_ascii($filename, $mapping);
    
    return 1;
}

my $clean_ascii_mask_help_text = qq[
    This command cleans a mask input file by translating all non-space characters to a '*', the default value for a '1' for the 
    'import_mask_from_ascii' command. The output will be placed in the same directory as the input file with a '.clean' extension.
];
sub clean_ascii_mask {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['str'],
        'required_descriptions' => ['input/output filename'],
        'help_text' => $clean_ascii_mask_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($filename) = $pparams->get_required();
    if (! -e $filename) {
        $state->report_error("'$filename' is not found.");
        return -1;
    }
    
    clean_ascii($filename);
    return 1;
}

my $mask_difference_help_text = qq[
    Finds the difference between two masks; if mask A has value '1' at coordinate X,Y while mask B has value '0' at the same coordinate (after applying the offset), then the result will have value '1', and otherwise '0'. For masks with decimal values, then the result is max(0, A-B). '--offsetX' and '--offsetY' specify how much to move B before the difference is taken; at any rate, the resulting mask will be stretched to encompass both A and B, including the offset.
];
sub mask_difference {
    my ($state, @params) = @_;
    return _two_op($state, $mask_difference_help_text, sub { my ($t, @r) = @_; return $t->difference(@r) }, @params);
}

my $mask_union_help_text = qq[
    Finds the union between two masks; if mask A has value '1' at coordinate X,Y while mask B has value '0' at the same coordinate (after applying the offset), then the result will have value '0', and otherwise '0'. For masks with decimal values, then the result is min(1, A+B). '--offsetX' and '--offsetY' specify how much to move B before the difference is taken; at any rate, the resulting mask will be stretched to encompass both A and B, including the offset.
];
sub mask_union {
    my ($state, @params) = @_;
    return _two_op($state, $mask_union_help_text, sub { my ($t, @r) = @_; return $t->union(@r) }, @params);
}

my $mask_intersect_help_text = qq[
    Finds the intersection between two masks; if mask A has value '1' at coordinate X,Y and mask B has value '1', the result will have value '1'; otherwise, if either value is '0', then the result will also be '0'. For masks with decimal values, then the result is A*B. offsetX and offsetY specify how much to move B before the difference is taken, while wrapX and wrapY determine whether B wraps. '--offsetX' and '--offsetY' specify how much to move B before the difference is taken; at any rate, the resulting mask will be stretched to encompass both A and B, including the offset.
];
sub mask_intersect {
    my ($state, @params) = @_;
    return _two_op($state, $mask_intersect_help_text, sub { my ($t, @r) = @_; return $t->intersection(@r) }, @params);
}

my $mask_invert_help_text = qq[
    Inverts a mask; that is, '1's become '0's and vice versa. For masks with decimal values, then the result is 1-value.
];
sub mask_invert {
    my ($state, @params) = @_;
    return _one_op($state, $mask_invert_help_text, '', sub { my ($t, @r) = @_; return $t->invert(@r) }, @params);
}

my $mask_threshold_help_text = qq[
    Swings values to either a '1' or a '0' depending on the threshold value, which is the second parameter to this command. Mask values below this value become a '0', and values above or equal become a '1'.
];
sub mask_threshold {
    my ($state, @params) = @_;
    return _one_op($state, $mask_threshold_help_text, 'float', sub { my ($t, @r) = @_; return $t->threshold(@r) }, @params);
}

sub _one_op {
    my ($state, $help_text, $has_other_arg, $sub, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'mask',
        'required' => ($has_other_arg ne '') ? ['mask', $has_other_arg] : ['mask'],
        'required_descriptions' => ['input mask'],
        'help_text' => $help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($target) = $pparams->get_required;
    my $result = $sub->($target);
    my $result_name = $pparams->get_result_name();
    $state->set_variable($result_name, 'mask', $result);
    
    return 1;
}

sub _two_op {
    my ($state, $help_text, $sub, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'mask',
        'required' => ['mask', 'mask'],
        'help_text' => $help_text,
        'required_descriptions' => ['mask A', 'mask B'],
        'optional' => {
            'offsetX' => 0,
            'offsetY' => 0
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($target, $with) = $pparams->get_required();
    my $offsetX = $pparams->get_named('offsetX');
    my $offsetY = $pparams->get_named('offsetY');
    my $result = $sub->($target, $with, $offsetX, $offsetY);
    
    my $result_name = $pparams->get_result_name();
    $state->set_variable($result_name, 'mask', $result);
    
    return 1;
}

my $count_mask_value_help_text = qq[
    Counts the number of values in the mask that match the target value. If '--threshold' is set, the mask will be thresholded first, and then counted.
];
sub count_mask_value {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['mask', 'float'],
        'required_descriptions' => ['mask to generate from', 'weight table used to translate values into terrain'],
        'help_text' => $count_mask_value_help_text,
        'optional' => {
            'threshold' => 'false',
            'threshold_value' => '0.5'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;

    my ($mask, $value) = $pparams->get_required();
    my $threshold_first = $pparams->get_named('threshold');
    my $threshold_value = $pparams->get_named('threshold_value');
    
    if ($threshold_first) {
        $mask = $mask->threshold($threshold_value);
    }
    
    my $count = $mask->count_matches($value);
    
    my $inv_count = $mask->get_width() * $mask->get_height() - $count;
    $state->list( "Matches: $count", "Non-Matches: $inv_count" );
    
    return 1;
}
    
my $generate_layer_from_mask_help_text = qq[
    Create a layer by applying a weight table to a mask. The value at each mask coordinate is evaluated according to the weight table, which is used to generate a new tile. For example, if the mask's value at coordinate 3,2 is equal to 0.45, and the weight table specifies that values
    between 0.4 and 1 map to an ordinary grassland tile, then the output layer will have a grassland tile at 3,2.
];
sub generate_layer_from_mask {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'layer',
        'required' => ['mask', 'weight'],
        'help_text' => $generate_layer_from_mask_help_text,
        'required_descriptions' => ['mask to generate from', 'weight table used to translate values into terrain'],
        'optional' => {
            'offsetX' => '0',
            'offsetY' => '0'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my ($group_name) = $result_name =~ /^(\$\w+)/;
    my ($layer_name) = $result_name =~ /(\w+)$/;
    my $group = $state->get_variable($group_name, 'group');
    
    my ($mask, $weight) = $pparams->get_required();
    my ($width, $height) = ($mask->get_width(), $mask->get_height());
    my $offsetX = $pparams->get_named('offsetX');
    my $offsetY = $pparams->get_named('offsetY');
    
    my ($layer) = Civ4MapCad::Object::Layer->new_default($layer_name, $width + abs($offsetX), $height + abs($offsetY));
    $layer->apply_mask($mask, $weight, $offsetX, $offsetY, 1);
    
    
    # TODO: this should just use set_variable
    my $result = $group->add_layer($layer);
    if (exists $result->{'error'}) {
        $state->report_warning($result->{'error_msg'});
    }
        
    $state->set_variable("\$$group_name.$layer_name", 'layer', $layer);
    return 1;
}

my $modify_layer_from_mask_help_text = qq[
    Modifies a layer by applying a weight table to a mask. The value at each mask coordinate is evaluated according to the weight table, which is used
    to *modify* the existing tile. Only differing attributes will be changed; this is useful if you want to just add bonuses to existing terrain with
    the bare_ weights and terrain, or if you want to modify terrain without touching the bonuses.
];
sub modify_layer_with_mask {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'layer',
        'help_text' => $modify_layer_from_mask_help_text,
        'allow_implied_result' => 1,
        'required' => ['layer', 'mask', 'weight'],
        'required_descriptions' => ['layer to modify', 'mask to generate from', 'weight table to generate terrain from'],
        'optional' => {
            'offsetX' => '0',
            'offsetY' => '0'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my ($group_name) = $result_name =~ /^(\$\w+)/;
    my ($layer_name) = $result_name =~ /(\w+)$/;
    my $group = $state->get_variable($group_name, 'group');
    
    my ($layer, $mask, $weight) = $pparams->get_required();
    my $offsetX = $pparams->get_named('offsetX');
    my $offsetY = $pparams->get_named('offsetY');
    my $copy = deepcopy($layer);
    
    $copy->apply_mask($mask, $weight, $offsetX, $offsetY, 0);
    
    my $result = $group->add_layer($copy);
    if (exists $result->{'error'}) {
        $state->report_warning($result->{'error_msg'});
    }
    
    $state->set_variable("\$$group_name.$layer_name", 'layer', $copy);
    return 1;
}

my $cutout_layer_with_mask_help_text = qq[
    todo 
];
sub cutout_layer_with_mask {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'layer',
        'help_text' => $cutout_layer_with_mask_help_text,
        'required' => ['layer', 'mask'],
        'required_descriptions' => ['layer to cutout from', 'mask to define selection'],
        'optional' => {
            'copy' => 'false',
            'offsetX' => '0',
            'offsetY' => '0'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my ($group_name) = $result_name =~ /^(\$\w+)/;
    my ($layer_name) = $result_name =~ /(\w+)$/;
    my $group = $state->get_variable($group_name, 'group');
    
    my ($layer, $mask) = $pparams->get_required();
    my $copy = $pparams->get_named('copy');
    my $clear = ($copy) ? 0 : 1;
    my $offsetX = $pparams->get_named('offsetX');
    my $offsetY = $pparams->get_named('offsetY');
    my $selected = $layer->select_with_mask($mask, $offsetX, $offsetY, $clear);
    
    $state->set_variable($result_name, 'layer', $selected);
    return 1;
}

my $apply_shape_to_mask_help_text = qq[
    todo
];
sub apply_shape_to_mask {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'layer',
        'allow_implied_result' => 1,
        'required' => ['mask', 'shape'],
        'required_descriptions' => ['mask to change', 'shape to apply'],
        'has_shape_params' => 1,
        'help_text' => $apply_shape_to_mask_help_text,
        'optional' => {
            'offsetX' => '0',
            'offsetY' => '0'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    die;
}

my $grow_mask_help_text = qq[ 
    Expands the mask a certain number of tiles. Only values of '1' are considered; thus, before the actual grow operation occurs, the mask is first thresholded. Use '--threshold' to set a custom threshold.
    The mask produced by this command will be larger in the input mask; all four directions will be stretched by the number of tiles that the mask is grown. If '--rescale' is set, the command attempts to
    keep the same size mask as long as there is empty space to chop away.
];
sub grow_mask {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'mask',
        'allow_implied_result' => 1,
        'help_text' => $grow_mask_help_text,
        'required' => ['mask', 'int'],
        'required_descriptions' => ['mask to grow', 'number of tiles to grow by'],
        'optional' => {
            'threshold' => 0.5,
            'rescale' => 'false'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my $threshold = $pparams->get_named('threshold');
    my $rescale = $pparams->get_named('rescale');
    my ($mask, $amount) = $pparams->get_required();
    
    my $grown = $mask->grow($amount, $threshold, $rescale);
    
    if (exists $grown->{'overfold_warning'}) {
        $state->report_warning("Mask size cannot be maintained constant without losing information. Allowing mask to grow instead and cropping at end.");
    }
    
    $state->set_variable($result_name, 'mask', $grown);
    return 1;
}

my $shrink_mask_help_text = qq[ 
    Contracts the mask a certain number of tiles. Only values of '0' are considered by the shrink; thus, before the actual shrink operation occurs, the mask is first thresholded. Use '--threshold' to set a custom threshold.
];
sub shrink_mask {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'mask',
        'allow_implied_result' => 1,
        'help_text' => $shrink_mask_help_text,
        'required' => ['mask', 'int'],
        'required_descriptions' => ['mask to shrink', 'number of tiles to shrink by'],
        'optional' => {
            'threshold' => 0.5,
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my $realign = $pparams->get_named('realign');
    my $threshold = $pparams->get_named('threshold');
    my ($mask, $amount) = $pparams->get_required();
    
    my $shrunk = $mask->shrink($amount, $threshold);
    $state->set_variable($result_name, 'mask', $shrunk);
    return 1;
}

my $set_mask_coord_help_text = qq[
    Sets a mask's value at a specific coordinate to a specific value.
];
sub set_mask_coord {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'mask',
        'allow_implied_result' => 1,
        'help_text' => $set_mask_coord_help_text,
        'required' => ['mask', 'int', 'int', 'float'],
        'required_descriptions' => ['the mask to modify', 'x coordinate', 'y coordinate', 'value to set']
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($mask, $x, $y, $value) = $pparams->get_required();
    my @names = $pparams->get_required_names();
    
    if (($x >= $mask->get_width()) or ($y >= $mask->get_height())) {
        my $size = $mask->get_width() . ' x ' . $mask->get_height();
        $state->report_error("Coordinate value ($x,$y) is out of bounds of mask (size: $size)");
        return -1;
    }
    
    my $copy = deepcopy($mask);
    $copy->{'canvas'}[$x][$y] = $value;
    
    $state->set_variable($names[0], 'mask', $copy);
    return 1;
}

my $mask_from_landmass_help_text = qq[
    Generate a mask based on a landmass. The starting tile must be a land tile; otherwise an error will be thrown. If '--choose_coast' is set, the mask will select be all water tiles adjacent to the landmass (i.e. its coast). If '--include_coast' is set, instead both the landmass and its coast will be selected. Finally, if '--include_ocean_resources' is set in addition to '--include_coast' or '--choose_coast', then all tiles containing ocean resources that are *adjacent* to a coast tile will be included.
];
sub mask_from_landmass {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'mask',
        'help_text' => $mask_from_landmass_help_text,
        'required' => ['layer', 'int', 'int'],
        'required_descriptions' => ['the layer to generate a mask from', 'x coordinate of starting tile', 'y coordinate of starting tile'],
        'optional' => {
            'choose_coast' => 'false',
            'include_coast' => 'false',
            'include_ocean_resources' => 'false'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my $choose_coast = $pparams->get_named('choose_coast');
    my $include_coast = $pparams->get_named('include_coast');
    my $include_ocean_res = $pparams->get_named('include_ocean_resources');
    my ($layer, $start_x, $start_y) = $pparams->get_required();
    my $copy = deepcopy($layer);
    
    $copy->fix_coast();
    my $start_tile = $copy->get_tile($start_x, $start_y);
    
    if (! defined($start_tile)) {
        $state->report_error("Layer " . $copy->get_full_name() . " is not defined at $start_x, $start_y.");
        return -1;
    }
    
    if (! $start_tile->is_land()) {
        $state->report_error("The starting tile at $start_x, $start_y is not land.");
        return -1;
    }
    
    if ($include_ocean_res and (!($include_coast or $choose_coast))) {
        $state->report_error("'--include_ocean_resources' can't be set without '--include_coast' or '--choose_coast'.");
        return -1;
    }
    
    my ($land, $water) = $copy->follow_land_tiles($start_tile, $include_ocean_res);
    ($land, $water) = ($water, $land) if $choose_coast == 1;
    
    my $mask = Civ4MapCad::Object::Mask->new_blank($copy->get_width(), $copy->get_height());
    
    while ( my($k,$v) = each %$land) {
        my ($x,$y) = split '/', $k;
        $mask->{'canvas'}[$x][$y] = 1;
    }
    
    if ($include_coast) {
        while ( my($k,$v) = each %$water) {
            my ($x,$y) = split '/', $k;
            $mask->{'canvas'}[$x][$y] = 1;
        }
    }
    
    $state->set_variable($result_name, 'mask', $mask);
    return 1;
}

my $mask_from_water_help_text = qq[
    Generate a mask based on a body of water. The starting tile must be a water tile; otherwise an error will be thrown. If '--only_coast' is set, the mask will only select tiles adjacent to land (i.e. the coast). If '--choose_land' is set, only land tiles adjacent to the body of water will be selected. '--only_coast' and '--choose_land' cannot both be 1 at the same time.
];
sub mask_from_water {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'mask',
        'help_text' => $mask_from_water_help_text,
        'required' => ['layer', 'int', 'int'],
        'required_descriptions' => ['the layer to generate a mask from', 'x coordinate of starting tile', 'y coordinate of starting tile'],
        'optional' => {
            'only_coast' => 'false',
            'choose_land' => 'false',
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my $only_coast = $pparams->get_named('only_coast');
    my $choose_land = $pparams->get_named('choose_land');
    my ($layer, $start_x, $start_y) = $pparams->get_required();
    my $copy = deepcopy($layer);
    
    $copy->fix_coast();
    my $start_tile = $copy->get_tile($start_x, $start_y);
    
    if (! defined($start_tile)) {
        $state->report_error("Layer " . $copy->get_full_name() . " is not defined at $start_x, $start_y.");
        return -1;
    }
    
    if (! $start_tile->is_water()) {
        $state->report_error("The starting tile at $start_x, $start_y is not water.");
        return -1;
    }
    
    if ($choose_land and $only_coast) {
        $state->report_error("--choose_land and --only_coast cannot both be used together.");
        return -1;
    }
    
    my ($land, $water) = $copy->follow_water_tiles($start_tile, $only_coast);
    ($land, $water) = ($water, $land) if $choose_land == 1;
    
    my $mask = Civ4MapCad::Object::Mask->new_blank($copy->get_width(), $copy->get_height());
    
    while ( my($k,$v) = each %$water) {
        my ($x,$y) = split '/', $k;
        $mask->{'canvas'}[$x][$y] = 1;
    }
    
    $state->set_variable($result_name, 'mask', $mask);
    return 1;
}

my $new_mask_from_magic_wand_help_text = qq[
    todo
];
sub new_mask_from_magic_wand {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_shape_params' => 1,
        'has_result' => 'mask',
        'required' => ['layer', 'weight', 'int', 'int'],
        'required_descriptions' => ['layer to select from', 'inverse weight to match to tiles', 'start coordinate X', 'start coordinate Y'],
        'help_text' => $new_mask_from_magic_wand_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my ($layer, $weight, $start_x, $start_y) = $pparams->get_required();
    my $copy = deepcopy($layer);
    
    $copy->fix_coast();
    my $start_tile = $copy->get_tile($start_x, $start_y);
    
    if (! defined($start_tile)) {
        $state->report_error("Layer " . $copy->get_full_name() . " is not defined at $start_x, $start_y.");
        return -1;
    }
    
    my $mask = Civ4MapCad::Object::Mask->new_blank($copy->get_width(), $copy->get_height());
    
    my (%checked, %nonexistant);
    
    my $is_already_checked = sub {
        my ($x, $y) = @_;
        return 1 if exists($checked{"$x/$y"}) or exists($nonexistant{"$x/$y"});
        return 0;
    };
    
    my $mark_as_checked = sub {
        my ($x, $y, $tile) = @_;
        
        if (! defined($tile)) {
            $nonexistant{"$x/$y"} = $tile;
        }
        else {
            $checked{"$x/$y"} = $tile;
        }
    };
    
    my $process = sub {
        my ($mark_as_checked, $tile) = @_;
        my ($x, $y) = ($tile->get('x'), $tile->get('y'));
        $mark_as_checked->($x, $y, $tile);
        
        my $value = $weight->inverse_evaluate($tile);
        if (defined($value)) {
            $mask->{'canvas'}[$x][$y] = $value;
            return 1;
        }
        
        return 0;
    };
    
    $layer->{'map'}->bfs_region_search($start_tile, $is_already_checked, $mark_as_checked, $process);
    $state->set_variable($result_name, 'mask', $mask);
    
    return 1;
}

1;