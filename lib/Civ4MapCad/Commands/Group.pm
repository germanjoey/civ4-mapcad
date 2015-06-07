package Civ4MapCad::Commands::Group;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(move_layer set_layer_priority cut_layer crop_layer extract_layer find_difference);

use Civ4MapCad::Util qw(_process_params);
use Civ4MapCad::Object::Layer;
use Civ4MapCad::Object::Group;

# take positive difference between mapobj a and mapobj b to create a new mapobj c, such that merging c onto a creates b
# ocean means "nothing", fallout over ocean means actual ocean.
# this acts on two flat groups
sub find_difference {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group', 'group']
    });
    return -1 if $pparams->error;
    
    my ($flat1, $flat2) = $pparams->get_required();
    
    my @layers1 = $flat->get_layer_names;
    my @layers2 = $flat->get_layer_names;
    
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
    return -1 if $pparams->error;
    
    my $result_name = $pparams->get_result_name();
    my ($width, $height) = $pparams->get_required();
    
    my $result = Civ4MapCad::Object::Group->new($result_name, $width, $height);
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
    return -1 if $pparams->error;
    
    my $result_name = $pparams->get_result_name();
    my ($filename) = $pparams->get_required();
    
    my $result = Civ4MapCad::Object::Group->new_from_import($filename);
    $state->set_variable($result_name, 'group', $result);
    
    return 1;
}

# add one 
sub copy_layer_from_group {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer', 'group']
        'optional' => {
            'new_name' => '',
        },
    });
    return -1 if $pparams->error;
    
    my $result_name = $pparams->get_result_name();
    my ($layer, $group) = $pparams->get_required();
    my $new_name = $pparams->get_named('new_name');
    $new_name = $layer->get_name() if $new_name eq '';
    
    my $groupname = $group->get_name();
    my $result = $group->add_layer($new_name, $layer);
    
    if ($result != 1) {
        $state->report_error("layer named $layer_name already exists in group '$groupname'.");
        return -1;
    }
    
    $state->set_variable("\$$groupname.$new_name", 'layer', $group->get_layer($new_name));
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
    return -1 if $pparams->error;
    
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
    return -1 if $pparams->error;
    
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
    return -1 if $pparams->error;
    
    my ($group) = $pparams->get_required();
    
    my $flat = $group->merge_all();
    my ($flat_layer) = $flat->get_layers();
    
    $flat_layer->export_layer($state->output_dir() . $flat->get_name() . ".flat.CivBeyondSwordWBSave");
    
    foreach my $layer ($group->get_layers()) {
        $flat_layer->export_layer($state->output_dir() . $flat->get_name() . ".flat.CivBeyondSwordWBSave");
    }
        
    return 1;
}

# return a mask highlighting each start
sub find_starts {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'has_result' => 'mask'
    });
    return -1 if $pparams->error;
    
    my ($group) = $pparams->get_required();
    my $result_name = $pparams->get_result_name();
    my $result = $group->find_starts();
    
    $state->set_variable($result_name, 'mask', $result);
    
    return 1;
}

sub export_sims {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
    });
    return -1 if $pparams->error;
    
    my $result_name = $pparams->get_result_name();
    
    # TODO: rewrite this with new methodology
    # first find starts
    # next apply BFC shape, creating a new mask
    # then apply that mask to the flattened group
    # then call export_group
    
    print "export_sims command executed\n\n";
    return 1;
}
