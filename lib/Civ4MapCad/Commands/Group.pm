package Civ4MapCad::Commands::Group;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    export_sims export_group combine_groups flatten_group import_group crop_group
    new_group find_difference normalize_starts expand_group_canvas strip_all_units
    strip_nonsettlers add_scouts_to_settlers extract_starts export_sims copy_group set_wrap
);

use Civ4MapCad::Util qw(deepcopy);
use Civ4MapCad::Object::Layer;
use Civ4MapCad::Object::Group;

my $set_wrap_help_text = qq[
    Sets wrap properties for a group and all its member layers. By default, all new blank groups wrap in both the X and Y dimensions; use this command in combination with the '--nowrapX' and/or '--nowrapY' flags to turn off wrap in the X and/or Y dimensions, respectively. If one of these flags is missing, the wrap value will default to 'true' for that direction.
];
sub set_wrap {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'help_text' => $set_wrap_help_text,
        'required' => ['group'],
        'required_descriptions' => ['group to set'],
        'optional' => {
            'nowrapX' => 'false',
            'nowrapY' => 'false'
        },
        'optional_descriptions' => {
            'nowrapX' => 'If set, the group and all its layers will be set not to wrap in the X direction. If missing, the group and all its layers *will* be set to wrap in the X direction.',
            'nowrapY' => 'If set, the group and all its layers will be set not to wrap in the Y direction. If missing, the group and all its layers *will* be set to wrap in the Y direction.'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($group) = $pparams->get_required();
    my $nowrapX = $pparams->get_named('nowrapX');
    my $nowrapY = $pparams->get_named('nowrapY');
    
    $group->set_wrapX(($nowrapX) ? 0 : 1);
    $group->set_wrapY(($nowrapY) ? 0 : 1);
    
    return 1;
}

my $expand_group_canvas_help_text = qq[
    Expands a group's dimensions by an extra amount.
];
sub expand_group_canvas {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group', 'int', 'int'],
        'required_descriptions' => ['group to expand', 'expand width by', 'expand height by'],
        'help_text' => $expand_group_canvas_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($group, $by_width, $by_height) = $pparams->get_required();
    
    my $width = $group->get_width();
    my $height = $group->get_height();
    
    $group->expand_dim($width + $by_width, $height + $by_height);
    return 1;
}

my $crop_group_help_text = qq[
    The group's dimensions are trimmed to left/bottom/right/top, from the nominal dimensions of 0 / 0 / width-1 / height-1. Any member layers that exceed these dimensions are cropped as well.
];
sub crop_group {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group', 'int', 'int', 'int', 'int'],
        'required_descriptions' => ['group to crop', 'left', 'bottom', 'right', 'top'],
        'has_result' => 'group',
        'allow_implied_result' => 1,
        'help_text' => $crop_group_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($group, $left, $bottom, $right, $top) = $pparams->get_required();
    
    my $width = $group->get_width();
    my $height = $group->get_height();
    
    my $x_ok = (($left >= 0) and ($right > $left) and ($right < $width));
    my $y_ok = (($bottom >= 0) and ($top > $bottom) and ($bottom < $height));
    
    unless ($x_ok and $y_ok) {
        $state->report_error("Dimensions are either out of bounds or crossed.");
        return -1;
    }
    
    my ($result_name) = $pparams->get_result_name();
    my $copy = ($result_name eq $group->get_full_name()) ? $group : deepcopy($group);
    
    $copy->crop($left, $bottom, $right, $top);
    $state->set_variable($result_name, 'group', $copy);
    
    return 1;
}

my $new_group_help_text = qq[
    Create a new group with a blank canvas with a size of width/height. The game settings and wrap properties for this group will be set when any layer is first added to it.
];
sub new_group {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'group',
        'required' => ['int', 'int'],
        'required_descriptions' => ['width', 'height'],
        'help_text' => $new_group_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my ($width, $height) = $pparams->get_required();
    
    my $result = Civ4MapCad::Object::Group->new_blank($result_name, $width, $height);
    $state->set_variable($result_name, 'group', $result);
    
    return 1;
}

my $import_group_help_text = qq[
    Create a new group by importing an existing worldbuilder file. The new group will have a single layer with the same name as the result group.
];
sub import_group { 
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'group',
        'required' => ['str'],
        'required_descriptions' => ['filename'],
        'help_text' => $import_group_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my ($filename) = $pparams->get_required();
    
    my $result = Civ4MapCad::Object::Group->new_from_import($filename);
    if (ref($result) eq '') {
        $state->report_error($result);
        return -1;
    }
    
    $result->set_difficulty($state->{'config'}{'difficulty'});
    $state->set_variable($result_name, 'group', $result);
    
    return 1;
}

my $copy_group_help_text = qq[
    Copy one group into duplicate with a different name.
];
sub copy_group {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to copy'],
        'has_result' => 'group',
        'help_text' => $copy_group_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($group) = $pparams->get_required();

    my ($result_name) = $pparams->get_result_name();
    my $copy = ($result_name eq $group->get_full_name()) ? $group : deepcopy($group);
    
    $state->set_variable($result_name, 'group', $copy);
    return 1;
}

# TODO: allow transparent tile to be specified as an optional argument via a terrain
my $flatten_group_help_text = qq[
    Flattens a group by merging all layers down, starting with the highest priority. Tiles at the same coordinates in an 'upper' layer will overwrite ones on a 'lower' layer. Ocean tiles are counted as "transparent" in the upper layer. Use the 'list_layers' command to see layer priorities.
];
sub flatten_group {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to flatten'],
        'has_result' => 'group',
        'allow_implied_result' => 1,
        'help_text' => $flatten_group_help_text,
        'optional' => {
            'rename_final_layer' => 'false'
        },
        'optional_descriptions' => {
            'rename_final_layer' => "If set, the final layer will be renamed to the same name as the group's name."
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($group) = $pparams->get_required();
    my ($rename_final) = $pparams->get_named('rename_final_layer');
    
    my @layers = $group->get_layers();
    if (@layers == 0) {
        $state->report_error("Can't flatten group: it has no layers!");
        return -1;
    }
    
    my ($result_name) = $pparams->get_result_name();
    my $copy = ($result_name eq $group->get_full_name()) ? $group : deepcopy($group);
    
    if ($rename_final) {
        my ($raw_name) = $result_name =~ /\$(\w+)/;
        $copy->rename_group($raw_name);
    }
    
    my $has_duplicate_owners = $group->has_duplicate_owners();
    $state->buffer_bar() if $has_duplicate_owners;
    my $ret = $copy->merge_all($rename_final);
    if (exists $ret->{'error'}) {
        $state->report_error($ret->{'error_msg'});
        return -1;
    }
    
    $state->register_print() if $has_duplicate_owners;
    $state->set_variable($result_name, 'group', $copy);
    
    return 1;
}

my $combine_groups_help_text = qq[
    Merges two groups A and B, into one; all layers in B will be placed under all layers in A. 
];
sub combine_groups {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group', 'group'],
        'required_descriptions' => ['group A', 'group B'],
        'has_result' => 'group',
        'allow_implied_result' => 1,
        'help_text' => $combine_groups_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my ($group, $other_group) = $pparams->get_required();
    
    my $result = $group->add_group($other_group);
    $state->set_variable($result_name, 'group', $result);
    
    return 1;
}

my $export_group_help_text = qq[
    Exports a flat version of the group as a CivBeyondSwordWBSave, in addition to also doing so for each layer seperately.
];
sub export_group {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to export'],
        'help_text' => $export_group_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($group) = $pparams->get_required();
    my $output_dir = $state->{'config'}{'output_dir'};
    my @layers = $group->get_layer_names();
    
    if (@layers == 0) {
        $state->report_error("Can't export group: it has no layers!");
        return -1;
    }
    
    $state->buffer_bar();
    
    if (@layers > 1) {
        # TODO: does this need cleanup?
        my $copy = deepcopy($group);
        print "\n  Exporting flat version of group ", $copy->get_name(), ".\n";
        
        my $has_duplicate_owners = $group->has_duplicate_owners();
        my $ret = $copy->merge_all(1);
        if (exists $ret->{'error'}) {
            $state->report_error($ret->{'error_msg'});
            return -1;
        }
        
        my ($flat_layer) = $copy->get_layers();
        $flat_layer->export_layer($output_dir . '/' . $copy->get_name() . ".flat.CivBeyondSwordWBSave");
        
        $copy->destroy_group($state);
    }
    
    $group->export($output_dir);
    $state->register_print();
    
    return 1;
}

my $normalize_starts_help_text = qq[
    Reorganizes a group's settlers so that each one is tied to a unique start, useful if, say, you mirror a common BFC design for every player. This command modifies the group.
    Note that this is always done automatically anyways when a group is exported.
];
sub normalize_starts {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to normalize'],
        'help_text' => $normalize_starts_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($group) = $pparams->get_required();
    
    my $has_duplicate_owners = $group->has_duplicate_owners();
    $state->buffer_bar() if $has_duplicate_owners;
    my $ret = $group->normalize_starts();
    
    if (exists $ret->{'error'}) {
        $state->report_error($ret->{'error_msg'});
        return -1;
    }
    
    $state->register_print() if $has_duplicate_owners;
    
    return 1;
}

my $add_scouts_to_settlers_help_text = qq[
    Wherever a settler is found in any layer, a scout is added on top of it. This command modifies the group.
];
sub add_scouts_to_settlers {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to add to'],
        'help_text' => $add_scouts_to_settlers_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my ($group) = $pparams->get_required();
    $group->add_scouts_to_settlers();
    
    return 1;
}

my $strip_all_units_help_text = qq[
    All units are removed from all layers. This command modifies the group.
];
sub strip_all_units {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to strip from'],
        'help_text' => $strip_all_units_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my ($group) = $pparams->get_required();
    $group->strip_all_units();
    
    return 1;
}

my $strip_nonsettlers_help_text = qq[
    All non-settler units are removed from all layers. This command modifies the group.
];
sub strip_nonsettlers {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to strip from'],
        'help_text' => $strip_nonsettlers_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my ($group) = $pparams->get_required();
    $group->strip_nonsettlers();
    
    return 1;
}

my $extract_starts_help_text = qq[
    The '\@bfc' mask is applied on each settler, and then that selected area is extracted as a new layer. 
];
sub extract_starts {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to extract from'],
        'has_result' => 'group',
        'allow_implied_result' => 1,
        'help_text' => $extract_starts_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($group) = $pparams->get_required();
    my $bfc = $state->get_variable('@bfc', 'mask');
    
    my ($result_name) = $pparams->get_result_name();
    my $copy = ($result_name eq $group->get_full_name()) ? $group : deepcopy($group);
    
    my $has_duplicate_owners = $copy->has_duplicate_owners();
    $state->buffer_bar() if $has_duplicate_owners;
    
    my $ret = $copy->merge_all(1);
    if (exists $ret->{'error'}) {
        $state->report_error($ret->{'error_msg'});
        return -1;
    }
    
    $state->register_print() if $has_duplicate_owners;
    $copy->extract_starts_with_mask($bfc, 0, 1);
    $state->set_variable($result_name, 'group', $copy);
    
    return 1;
}

my $export_sims_help_text = qq[
    The '\@bfc' mask is applied on each settler, and then that selected area is extracted as a new layer. The group is then exported ala the 'export_group' command, with each layer being saved as its own CivBeyondSwordWBSave. This command does not modify the  group.
];
sub export_sims {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to extract from'],
        'help_text' => $export_sims_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $output_dir = $state->{'config'}{'output_dir'};
    my ($group) = $pparams->get_required();
    my $copy = deepcopy($group);
    
    my $width = $copy->get_width();
    my $height = $copy->get_height();
    
    my $bfc = $state->get_variable('@bfc', 'mask');
    my $bfc_for_sim = Civ4MapCad::Object::Mask->new_blank($width, $height);
    #$bfc_for_sim = $bfc_for_sim->union($bfc, int($width/2)-6, int($height/2)-6);
    $bfc_for_sim = $bfc_for_sim->union($bfc, int($width/2)-2, int($height/2)-2);
    
    my @layers = $group->get_layer_names();
    if (@layers == 0) {
        $state->report_error("Can't export group: it has no layers!");
        return -1;
    }
    
    my $has_duplicate_owners = $copy->has_duplicate_owners();
    $state->buffer_bar() if $has_duplicate_owners;
    my $ret = $copy->merge_all(1);
    if (exists $ret->{'error'}) {
        $state->report_error($ret->{'error_msg'});
        return -1;
    }
    
    $state->register_print() if $has_duplicate_owners;

    $copy->extract_starts_with_mask($bfc_for_sim, 1, 0);
    $copy->export($output_dir);
    $copy->destroy_group($state);
    
    return 1;
}

my $find_difference_help_text = qq[
    Take a positive difference between mapobj a and mapobj b to create a new mapobj c, such that merging c onto a creates b
    ocean means "nothing", and fallout over ocean means actual ocean. Basically, this is useful if you're creating a map in
    pieces and want to do hand-edits in the middle. That way, you can regenerate the map from scratch while still including
    your hand-edits. This command acts on two flat groups, so merge all layers first if you need to.
];
sub find_difference {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'group',
        'required' => ['group', 'group'],
        'required_descriptions' => ['group A', 'group B'],
        'help_text' => $find_difference_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $result_name = $pparams->get_result_name();
    my ($flat1, $flat2) = $pparams->get_required();
    
    my @layers1 = $flat1->get_layer_names();
    my @layers2 = $flat2->get_layer_names();
    
    if ((@layers1 > 1) or (@layers2 > 1)) {
        $state->report_error("find_difference requires that both groups first be flattened.");
        return -1;
    }
    
    my $result = $flat1->find_difference($flat2);
    $state->set_variable($result_name, 'group', $result);
    
    return 1;
}

1;
