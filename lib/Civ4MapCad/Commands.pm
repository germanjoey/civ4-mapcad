package Civ4MapCad::Commands;

use strict;
use warnings;

use Exporter::Dispatch;
use Civ4MapCad::ParamParser;

use Civ4MapCad::Util;

use Civ4MapCad::Commands::Config qw(
   set_output_dir set_mod write_log history
);

use Civ4MapCad::Commands::Weight qw(
    load_terrain new_weight_table import_weight_table_from_file
);
use Civ4MapCad::Commands::List qw(
    list_shapes list_groups list_layers list_masks list_weights list_terrain
    show_weights dump_group dump_mask dump_layer dump_mask_to_console evaluate_weight
);

use Civ4MapCad::Commands::Mask qw(
    new_mask_from_magic_wand new_mask_from_shape mask_difference mask_union mask_intersect
    mask_invert mask_threshold modify_layer_with_mask cutout_layer_with_mask apply_shape_to_mask
    generate_layer_from_mask import_mask_from_ascii export_mask_to_ascii export_mask_to_table
    import_mask_from_table set_mask_coord
);

use Civ4MapCad::Commands::Layer qw(
    move_layer set_layer_priority cut_layer crop_layer extract_layer find_difference flip_layer_tb
    flip_layer_lr copy_layer_from_group merge_two_layers expand_layer_canvas
    increase_layer_priority decrease_layer_priority set_tile
);

use Civ4MapCad::Commands::Group qw(
    export_sims find_starts export_group combine_groups flatten_group import_group
    new_group find_difference extract_starts_as_mask normalize_starts find_starts 
    strip_nonsettlers add_scouts_to_settlers extract_starts export_sims copy_group
    crop_group expand_group_canvas set_wrap
);

# use Civ4MapCad::Commands::Balance qw();

our $global_state;

my $import_shape_help_text = qq[
    TODO
];
sub import_shape {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'shape',
        'required' => ['str'],
        'required_descriptions' => ['path'],
        'help_text' => $import_shape_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
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
        delete $INC{$path} if exists $INC{$path};
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
    $global_state->{'shape_param'}{$global_state->{'shape_name'}} = Civ4MapCad::Util::deepcopy($params);
    
    delete $global_state->{'shape_name'};
    $global_state->{'registering'} = 0;
    return 1;
}

sub run_script {
    my ($state, @params) = @_;

    if ((@params == 1) and ($params[0] eq '--help')) {
        $state->buffer_bar();
        
        print "\n";
        print "  Command format:";
        print "\n\n";
        print "  run_script \"string\"\ => optional_result_name\n    param 1: filename of script to run";
        print "\n\n";
        print "  Loads a script and runs the commands within. A result to this command may be\n";
        print "  specified; if so, then the 'return' command may be used in the script to\n";
        print "  return a result. The result may be any type (group/layer/mask/weight) but must\n";
        print "  match the type returned by the script.\n\n";
        
        $state->register_print();
        return 1;
    }
    
    my $error = 0;
    my $result_name = '';
    if (@params == 3) {
        if ($params[1] eq '=>' and ($params[2] =~ /[\*\$\@\%]?\w+(?:\.\w+)?/)) {
            my $result_name = pop @params;
            my $op = pop @params;
            
            my $type = $state->get_variable_type_from_name($result_name);
            if (exists $type->{'error'}) {
                $state->report_error($type->{'error_msg'});
                return -1;
            }
            
            my $result_type = $type->{'type'};
            $state->push_script_return($result_name, $result_type);
        }
        else {
            $error = 1;
        }
    }
    
    if ((@params != 1) or ((@params == 1) and ($params[0] !~ /^"[^"]+"$/))) {
        $error = 1;
    }
    
    if ($error) {
        $state->report_error("run_script requires a single string argument containing the path to the script to run, and allows an optional result.");
        print "  Command format:\n\n";
        print "  run_script \"string\"\ => optional_result_name\n    param 1: filename of script to run\n\n";
        
        return -1;
    }

    my $filename = $params[0];
    $filename =~ s/\"//g;
    
    $state->in_script();
    my $ret = $state->process_script($filename);
    $state->off_script();
    
    return $ret;
}

1;
