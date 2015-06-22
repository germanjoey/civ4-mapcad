package Civ4MapCad::Commands::Group;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    export_sims find_starts export_group combine_groups flatten_group copy_layer_from_group import_group new_group find_difference
    extract_starts_as_mask extract_starts_as_layers normalize_starts find_starts strip_nonsettlers add_scouts_to_settlers extract_starts export_sims
);

use Civ4MapCad::Util qw(deepcopy);
use Civ4MapCad::Object::Layer;
use Civ4MapCad::Object::Group;

# take positive difference between mapobj a and mapobj b to create a new mapobj c, such that merging c onto a creates b
# ocean means "nothing", fallout over ocean means actual ocean.
# this acts on two flat groups
sub find_difference {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => ['group'],
        'required' => ['group', 'group']
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

# create a blank canvas; need width and height
sub new_group {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'group',
        'required' => ['int', 'int']
    });
    return -1 if $pparams->has_error;
    
    my $result_name = $pparams->get_result_name();
    my ($width, $height) = $pparams->get_required();
    
    my $result = Civ4MapCad::Object::Group->new_blank($result_name, $width, $height);
    $state->set_variable($result_name, 'group', $result);
    
    return 1;
}

# import an existing wb save as a map object into the map object folder for this game
sub import_group { 
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'group',
        'required' => ['str']
    });
    return -1 if $pparams->has_error;
    
    my $result_name = $pparams->get_result_name();
    my ($filename) = $pparams->get_required();
    $filename =~ s/"//g;
    
    my $result = Civ4MapCad::Object::Group->new_from_import($filename);
    $state->set_variable($result_name, 'group', $result);
    
    return 1;
}

# add one 
sub copy_layer_from_group {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer', 'group'],
        'optional' => {
            'new_name' => '',
        },
    });
    return -1 if $pparams->has_error;
    
    my $result_name = $pparams->get_result_name();
    my ($layer, $group) = $pparams->get_required();
    my $new_name = $pparams->get_named('new_name');
    my $copy = deepcopy($layer);
    $copy->rename($new_name) if $new_name eq '';
    
    my $group_name = $group->get_name();
    my $result = $group->add_layer($copy);
    
    if ($result != 1) {
        $state->report_warning("layer named $new_name already exists in group '$group_name'... overwriting.");
        return -1;
    }
    
    $state->set_variable("\$$group_name.$new_name", 'layer', $copy);
    return 1;
}

# flatten a map object's blocks in preference for priority
# ocean means "nothing" (no overwriting), fallout over ocean means actual ocean (a gets written over with regular ocean).
sub flatten_group {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'allow_implied_result' => 1,
    });
    return -1 if $pparams->has_error;
    
    my $result_name = $pparams->get_result_name();
    my ($group) = $pparams->required();
    
    my $result = $group->merge_all();
    $state->set_variable($result_name, 'group', $result);
    
    return 1;
}

sub combine_groups {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group', 'group'],
        'has_result' => 'group',
        'allow_implied_result' => 1,
    });
    return -1 if $pparams->has_error;
    
    my $result_name = $pparams->get_result_name();
    my ($group, $other_group) = $pparams->get_required();
    
    my $result = $group->add_group($other_group);
    $state->set_variable($result_name, 'group', $result);
    
    return 1;
}

# flatten a map and save as a worldbuilder file; also save each layer separately
sub export_group {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
    });
    return -1 if $pparams->has_error;
    
    my ($group) = $pparams->get_required();
    
    my $flat = $group->merge_all();
    my ($flat_layer) = $flat->get_layers();
    
    $flat_layer->export_layer($state->output_dir() . $flat->get_name() . ".flat.CivBeyondSwordWBSave");
    
    foreach my $layer ($group->get_layers()) {
        $flat_layer->export_layer($state->output_dir() . $flat->get_name() . ".flat.CivBeyondSwordWBSave");
    }
        
    return 1;
}

sub extract_starts_as_layers {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        
        'optional' => {
            'settler_only' => 0
        }
    });
    return -1 if $pparams->has_error;
    
    my ($group) = $pparams->get_required();
    my $result_name = $pparams->get_result_name();
    my $result = $group->find_starts();
    
    
    
    return 1;
}

# return a mask highlighting each start
sub extract_starts_as_mask {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'has_result' => 'mask'
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

sub normalize_starts {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group']
    });
    return -1 if $pparams->has_error;
    
    my ($group) = $pparams->get_required();
    $group->normalize_starts();
    
    return 1;
}

sub add_scouts_to_settlers {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group']
    });
    return -1 if $pparams->has_error;
    
    my $result_name = $pparams->get_result_name();
    my ($group) = $pparams->get_required();
    my $copy = deepcopy($group);
    
    $copy->add_scouts_to_settlers();
    $state->set_variable($result_name, 'group', $copy);
    
    return 1;
}

sub strip_all_units {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'has_result' => 'group',
        'allow_implied_result' => 1
    });
    return -1 if $pparams->has_error;
    
    my $result_name = $pparams->get_result_name();
    my ($group) = $pparams->get_required();
    my $copy = deepcopy($group);
    
    $copy->strip_all_units();
    $state->set_variable($result_name, 'group', $copy);
    
    return 1;
}

sub strip_nonsettlers {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'has_result' => 'group',
        'allow_implied_result' => 1
    });
    return -1 if $pparams->has_error;
    
    my $result_name = $pparams->get_result_name();
    my ($group) = $pparams->get_required();
    my $copy = deepcopy($group);
    
    $copy->strip_nonsettlers();
    $state->set_variable($result_name, 'group', $copy);
    
    return 1;
}

sub extract_starts {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'has_result' => 'group',
        'allow_implied_result' => 1
    });
    return -1 if $pparams->has_error;
    
    my $result_name = $pparams->get_result_name();
    my ($group) = $pparams->get_required();
    $group->normalize_starts();
    
    my $bfc = $state->get_variable('@bfc_tight', 'mask');
    my $new_group = $group->extract_starts_with_mask($bfc);
    $state->set_variable($result_name, 'group', $new_group);
    return 1;
}

sub export_sims {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'optional' => {
            'output_dir' => '.',
            'delete_existing' => 0
        }
    });
    return -1 if $pparams->has_error;
    
    my $output_dir = $pparams->get_named('output_dir');
    my $delete_existing = $pparams->get_named('delete_existing');
    my ($group) = $pparams->get_required();
    my $copy = deepcopy($group);
    
    $copy->normalize_starts();
    my $bfc = $state->get_variable('@bfc_for_sim', 'mask');
    
    # TODO: add a dummy AI in top corner
    
    $copy->extract_starts_with_mask($bfc);
    $copy->export($output_dir);
    
    return 1;
}
