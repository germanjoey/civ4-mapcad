package Civ4MapCad::Commands::Group;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    export_sims find_starts export_group combine_groups flatten_group import_group new_group find_difference
    extract_starts_as_mask normalize_starts find_starts strip_nonsettlers add_scouts_to_settlers extract_starts export_sims
    copy_group
);

use Civ4MapCad::Util qw(deepcopy);
use Civ4MapCad::Object::Layer;
use Civ4MapCad::Object::Group;

my $set_wrap_help_text = qq[
    
];
sub set_wrap {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to set'],
        'optional' => {
            'wrapX' => 'true',
            'wrapY' => 'true'
        },
        'help_text' => $set_wrap_help_text
    });
    return -1 if $pparams->has_error;
}

my $crop_group_help_text = qq[
    
];
sub crop_group {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group', 'int', 'int', 'int', 'int'],
        'required_descriptions' => ['group to crop', 'left', 'bottom', 'right', 'top'],
        'has_result' => ['group'],
        'allow_implied_result' => 1,
        'help_text' => $crop_group_help_text
    });
    return -1 if $pparams->has_error;
}

my $new_group_help_text = qq[
    Create a new group with a blank canvas with a size of width/height. The new group will have a single layer with the same name as the result group.
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
    
    my $result_name = $pparams->get_result_name();
    my ($width, $height) = $pparams->get_required();
    
    my $result = Civ4MapCad::Object::Group->new_blank($result_name, $width, $height);
    $state->set_variable($result_name, 'group', $result);
    
    return 1;
}

# import an existing wb save as a map object into the map object folder for this game
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
    
    my $result_name = $pparams->get_result_name();
    my ($filename) = $pparams->get_required();
    $filename =~ s/"//g;
    
    my $result = Civ4MapCad::Object::Group->new_from_import($filename);
    if (ref($result) eq '') {
        $state->report_error($result);
        return -1;
    }
    
    $state->set_variable($result_name, 'group', $result);
    
    return 1;
}

my $copy_group_help_text = qq[
    Copy one group into another.
];
sub copy_group {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to copy'],
        'has_result' => 'group',
        'help_text' => $copy_group_help_text
    });
    
    my ($group) = $pparams->get_required();
    my $copy = deepcopy($group);
    
    my $result_name = $pparams->get_result_name();
    $copy->rename($result_name);
    
    $state->set_variable($result_name, 'group', $copy);
}

# TODO: allow transparent tile to be specified as an optional argument via a terrain
my $flatten_group_help_text = qq[
    Flattens a group by merging all layers down, starting with the highest priority. Tiles at the same coordinates in an 'upper' layer will overwrite ones on a 'lower' layer. Ocean tiles are counted as "transparent" in the upper layer. If you do not specify a result, the group will be overwritten. If the '--rename_final' flag is set, the final layer will be renamed to the same name as the group's name.
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
            'rename_final' => 'false'
        }
    });
    return -1 if $pparams->has_error;
    
    my $result_name = $pparams->get_result_name();
    my ($group) = $pparams->get_required();
    my ($rename_final) = $pparams->get_named('rename_final');
    
    my $result = $group->merge_all($rename_final);
    $state->set_variable($result_name, 'group', $result);
    
    return 1;
}

my $combine_groups_help_text = qq[
    Merges two groups A and B, into one; all layers in B will be placed under all layers in A. If a result is not specified, Group A will be overwritten.
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
    
    my $result_name = $pparams->get_result_name();
    my ($group, $other_group) = $pparams->get_required();
    
    my $result = $group->add_group($other_group);
    $state->set_variable($result_name, 'group', $result);
    
    return 1;
}

my $export_group_help_text = qq[
    Exports a flat version of the group as a CivBeyondSwordWBSave in addition to also doing so for each layer seperately.
];
sub export_group {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to export'],
        'help_text' => $export_group_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($group) = $pparams->get_required();
    my $output_dir = $main::config{'output_dir'};
    my @layers = $group->get_layer_names();
    
    if (@layers > 0) {
        my $flat = $group->merge_all();
        my ($flat_layer) = $flat->get_layers();
        $flat_layer->export_layer($output_dir . '/' . $flat->get_name() . ".flat.CivBeyondSwordWBSave");
    }
    
    $group->export($output_dir);
        
    return 1;
}

# return a mask highlighting each start

my $extract_starts_as_mask_help_text = qq[
    Return a group of masks highlighting each start... not yet implemented.
];
sub extract_starts_as_mask {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to extract from'],
        'has_result' => 'mask',
        'help_text' => $extract_starts_as_mask_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($group) = $pparams->get_required();
    my $result_name = $pparams->get_result_name();
    my $starts = $group->find_starts();
    
    # TODO: what do I really want to do here? we need some kind of "MaskGroup" object
    # I think... something to think about after basic functionality is done.
    die;
    
    return 1;
}

my $normalize_starts_help_text = qq[
    Reorganizes a group's settlers so that each one is tied to a unique start, useful if, say, you mirror a common BFC design for every player. This command modifies the group.
];
sub normalize_starts {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to normalize'],
        'help_text' => $normalize_starts_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($group) = $pparams->get_required();
    $group->normalize_starts();
    
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
    
    my $result_name = $pparams->get_result_name();
    my ($group) = $pparams->get_required();
    $group->strip_all_units();
    
    return 1;
}

my $strip_nonsettlers_help_text = qq[
    All non-settler units are removed from all layers. If a result is not specified, this command modifies the group.
];
sub strip_nonsettlers {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to strip from'],
        'help_text' => $strip_nonsettlers_help_text
    });
    return -1 if $pparams->has_error;
    
    my $result_name = $pparams->get_result_name();
    my ($group) = $pparams->get_required();
    $group->strip_nonsettlers();
    
    return 1;
}

my $extract_starts_help_text = qq[
    The '\@bfc_tight' mask is applied on each settler, and then that selected area is extracted as a new layer. If a result is not specified, this command modifies the group.
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
    
    my $result_name = $pparams->get_result_name();
    my ($group) = $pparams->get_required();
    
    my $copy = deepcopy($group);
    $copy->normalize_starts();
    
    my $bfc = $state->get_variable('@bfc_tight', 'mask');
    $copy->extract_starts_with_mask($bfc);
    $state->set_variable($result_name, 'group', $copy);
    return 1;
}

# TODO: respect delete_existing
my $export_sims_help_text = qq[
    The '\@bfc_for_sim' mask is applied on each settler, and then that selected area is extracted as a new layer. The group is then exported ala the 'export_group' command, with each layer being saved as its own CivBeyondSwordWBSave. This command does not modify the specified group.
];
sub export_sims {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to extract from'],
        'help_text' => $export_sims_help_text,
        'optional' => {
            'delete_existing' => 'false'
        }
    });
    return -1 if $pparams->has_error;
    
    my $output_dir = $main::config{'output_dir'};
    my $delete_existing = $pparams->get_named('delete_existing');
    my ($group) = $pparams->get_required();
    my $copy = deepcopy($group);
    
    $copy->normalize_starts();
    my $bfc = $state->get_variable('@bfc_for_sim', 'mask');
    
    $copy->extract_starts_with_mask($bfc);
    $copy->export($output_dir);
    
    return 1;
}

my $find_difference_help_text = qq[
    Take positive difference between mapobj a and mapobj b to create a new mapobj c, such that merging c onto a creates b
    ocean means "nothing", fallout over ocean means actual ocean. Basically, this is useful if you're creating a map in
    pieces and want to do hand-edits in the middle. That way, you can regenerate the map from scratch while still including
    your hand-edits. This command acts on two flat groups, so merge all layers first if you need to.
];
sub find_difference {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => ['group'],
        'required' => ['group', 'group'],
        'required_descriptions' => ['group A', 'group B'],
        'help_text' => $find_difference_help_text
    });
    return -1 if $pparams->has_error;
    
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
