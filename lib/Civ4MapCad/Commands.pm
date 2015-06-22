package Civ4MapCad::Commands;

use strict;
use warnings;

use Exporter::Dispatch;
use Civ4MapCad::ParamParser;

use Civ4MapCad::Commands::TopLevel qw(
   set_output_dir write_log
);
use Civ4MapCad::Commands::Weight qw(
    load_terrain new_weight_table import_weight_table_from_file
);
use Civ4MapCad::Commands::List qw(
    list_shapes list_groups list_layers list_masks list_weights show_weights
    new_weight_table dump_group dump_mask dump_layer
);
use Civ4MapCad::Commands::Mask qw(
    import_mask_from_ascii new_mask_from_shape mask_difference mask_union
    mask_intersect mask_invert mask_threshold
);
use Civ4MapCad::Commands::Layer qw(
    move_layer set_layer_priority cut_layer crop_layer extract_layer find_difference
);
use Civ4MapCad::Commands::Group qw(
    export_sims find_starts export_group combine_groups flatten_group copy_layer_from_group import_group new_group find_difference
    extract_starts_as_mask extract_starts_as_layers normalize_starts find_starts strip_nonsettlers add_scouts_to_settlers extract_starts export_sims
);

# use Civ4MapCad::Commands::Balance qw();

our $global_state;

sub import_shape {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'shape',
        'required' => ['str']
    });
    return -1 if $pparams->has_error;
    
    my $shape_name = $pparams->get_result_name();
    my ($path) = $pparams->get_required();
    $path =~ s/"//g;    
    
    if (exists $state->{'shape'}{$shape_name}) {
        $state->report_warning("shape with name '$shape_name' already exists.");
    }
    
    if ($path eq '') {
        $state->report_error("no path was specified to import shape definition for '$shape_name'.");
        return -1;
    }
    
    $global_state = $state;
    $state->{'registering'} = 1;
    $state->{'shape_name'} = $shape_name;
    
    eval {
        no strict 'refs';
        no warnings 'redefine';
        require "$path";
    };
    if ($@) {
        $state->report_error("registration of shape '$shape_name' did not complete successfully: $@.");
        return -1;
    }
    
    # if we still equal 1, then there was a problem registering shape
    if ($state->{'registering'} == 1) {
        $state->report_error("registration of shape '$shape_name' did not complete for unknown reasons.");
        return -1;
    }
    
    return 1;
}

sub register_shape {
    my ($params, $gen) = @_;
    
    $global_state->{'shape'}{$global_state->{'shape_name'}} = $gen;
    $global_state->{'shape_param'}{$global_state->{'shape_name'}} = $params;
    
    delete $global_state->{'shape_name'};
    $global_state->{'registering'} = 0;
    return 1;
}

1;
