package Civ4MapCad::Commands::Mask;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(import_mask_from_ascii new_mask_from_shape mask_difference mask_union mask_intersect 
                    mask_invert mask_threshold modify_layer_with_mask cutout_layer_with_mask apply_shape_to_mask  
                    generate_layer_from_mask new_mask_from_magic_wand export_mask_to_ascii
                    export_mask_to_table import_mask_from_table);

use Civ4MapCad::Util qw(deepcopy);
use Civ4MapCad::ParamParser;
use Civ4MapCad::Object::Mask;
use Civ4MapCad::Ascii qw(clean_ascii import_ascii_mapping_file);

my $new_mask_from_magic_wand_help_text = qq[
    
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
    
    die "not yet implemented";
}

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
    
    my ($target, $with) = $pparams->get_required();
    my $offsetX = $pparams->get_named('offsetX');
    my $offsetY = $pparams->get_named('offsetY');
    my $result = $sub->($target, $with, $offsetX, $offsetY);
    
    my $result_name = $pparams->get_result_name();
    $state->set_variable($result_name, 'mask', $result);
    
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
    
    my $result = $group->add_layer($layer);
    if (exists $result->{'error'}) {
        $state->report_warning($result->{'error_msg'});
    }
        
    $state->set_variable("\$$group_name.$layer_name", 'layer', $layer);
    return 1;
}

sub modify_layer_with_mask {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'layer',
        'allow_implied_result' => 1,
        'required' => ['layer', 'mask', 'weight'],
        'required_descriptions' => ['layer to modify', 'mask to generate from', 'weight table to generate terrain from'],
        'optional' => {
            'offsetX' => '0',
            'offsetY' => '0'
        }
    });
    return -1 if $pparams->has_error;
    
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

sub cutout_layer_with_mask {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'layer',
        'required' => ['layer', 'mask'],
        'required_descriptions' => ['layer to cutout from', 'mask to define selection'],
        'optional' => {
            'copy' => 'false',
            'offsetX' => '0',
            'offsetY' => '0'
        }
    });
    return -1 if $pparams->has_error;
    
    my $result_name = $pparams->get_result_name();
    my ($group_name) = $result_name =~ /^(\$\w+)/;
    my ($layer_name) = $result_name =~ /(\w+)$/;
    my $group = $state->get_variable($group_name, 'group');
    
    my ($layer, $mask) = $pparams->get_required();
    my $copy = $pparams->get_named('copy');
    my $clear = ($copy) ? 0 : 1;
    my $offsetX = $pparams->get_named('offsetX');
    my $offsetY = $pparams->get_named('offsetY');
    my $selected = $layer->select_with_mask($mask, $offsetX, $offsetY, $clear) = @_;
    
    my $result = $group->add_layer($selected);
    if (exists $result->{'error'}) {
        $state->report_warning($result->{'error_msg'});
    }
    
    $state->set_variable("\$$group_name.$layer_name", 'layer', $selected);
}

sub apply_shape_to_mask {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'layer',
        'has_shape_params' => 1,
        'allow_implied_result' => 1,
        'required' => ['mask', 'layer'],
        'required_descriptions' => [],
        'optional' => {
            'copy' => 'false',
            'offsetX' => '0',
            'offsetY' => '0'
        }
    });
    return -1 if $pparams->has_error;
    
    die;
}

1;