package Civ4MapCad::Commands;

use strict;
use warnings;

use Exporter::Dispatch;
use Civ4MapCad::ParamParser;

use Civ4MapCad::Commands::Balance qw(
   balance_report fix_map
);

use Civ4MapCad::Commands::Config qw(
   set_output_dir list_mods set_mod write_log history load_xml_data set_player_data set_difficulty ls set_settings add_sign
);

use Civ4MapCad::Commands::Weight qw(
    load_terrain new_weight_table import_weight_table_from_file
);

use Civ4MapCad::Commands::Debug qw(
    debug_group debug_mask debug_layer debug_weight debug_mask_in_console evaluate_weight evaluate_weight_inverse show_weights 
);

use Civ4MapCad::Commands::List qw(
    list_shapes list_groups list_layers list_masks list_weights show_difficulty
    list_terrain list_civs list_leaders list_colors list_techs list_traits find_starts
);

use Civ4MapCad::Commands::Mask qw(
    new_mask_from_magic_wand new_mask_from_shape mask_difference mask_union mask_intersect
    mask_invert mask_threshold modify_layer_with_mask cutout_layer_with_mask apply_shape_to_mask
    generate_layer_from_mask import_mask_from_ascii export_mask_to_ascii set_mask_coord
    export_mask_to_table import_mask_from_table new_mask_from_water new_mask_from_landmass
    new_mask_from_polygon grow_mask shrink_mask count_mask_value new_mask_from_filtered_tiles
    rotate_mask mask_eval2 mask_eval1 grow_mask_by_bfc count_tiles delete_from_layer_with_mask
);

use Civ4MapCad::Commands::Layer qw(
    move_layer_to_location move_layer_by set_layer_priority crop_layer rename_layer delete_layer
    flip_layer_tb flip_layer_lr copy_layer_from_group merge_two_layers expand_layer_canvas
    increase_layer_priority decrease_layer_priority set_tile rotate_layer strip_all_units_from_layer
);

use Civ4MapCad::Commands::Group qw(
    export_sims export_group combine_groups flatten_group import_group crop_group
    new_group find_difference normalize_starts expand_group_canvas strip_all_units
    strip_nonsettlers add_scouts_to_settlers extract_starts copy_group set_wrap
    
);

our $global_state;

my $import_shape_help_text = qq[
    Imports a shape module from the shapes/ directory, probably during the Civ4MC bootup phase. 
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
        print "  run_script \"string\"\ [ --debug_result ] => optional_result_name\n    param 1: filename of script to run";
        print "\n\n";
        print "  Description:\n";
        print "  Loads a script and runs the commands within. A result to this command may be\n";
        print "  specified; if so, then the 'return' command may be used in the script to\n";
        print "  return a result. The result may be any type (group/layer/mask/weight) but\n";
        print "  must match the type returned by the script. If '--debug_result' is specified,\n";
        print "  the return value will be sent to the html view as if you used debug_group,\n";
        print "  debug_mask, etc.\n\n";
        
        $state->register_print();
        return 1;
    }
  
    # duplicate some code from ParamParser; condense strings with spaces in the name
    my $open_string = 0;
    my $current_string = '';
    my @proc_params;
    foreach my $part (@params) {
        if (($open_string == 1) or ($part =~ /^\"/)) {
            $open_string = 1;
            $current_string .= $part;
            
            if ($part =~ /\"$/) {
                push @proc_params, $current_string;
                
                $open_string = 0;
                $current_string = '';
            }
            else {
                $current_string .= ' ';
            }
            
            next;
        }
        
        push @proc_params, $part;
    }
    
    if ($open_string) {
        $state->report_error("parse error, string was found to have an open quote.");
        return -1;
    }
  
    my $error = 0;
    
    my $expects_return = 0;
    my $result_name = '';
    my $result_type = '';
    my $debug_result = 0;
    
    if (@proc_params > 1) {
        if (($proc_params[1] eq '=>') and ($proc_params[2] =~ /[\*\$\@\%]?\w+(?:\.\w+)?/)) {
            $result_name = pop @proc_params;
            my $op = pop @proc_params;
            
            my $type = $state->get_variable_type_from_name($result_name);
            if (exists $type->{'error'}) {
                $state->report_error($type->{'error_msg'});
                return -1;
            }
            
            # if we have a layer result, make sure the group exists first!
            if ($result_name =~ /^\$(\w+)\.(\w+)/) {
                my ($group_name) = $result_name =~ /^(\$\w+)/;
                if (! $state->variable_exists($group_name, 'group')) {
                    $state->report_error("a variable of type group named '$group_name' used in the result does not exist.");
                    return -1;
                }
            }
            
            $expects_return = 1;
            $result_type = $type->{'type'};
        }
    }
    
    if (@proc_params == 2) {
        if ($proc_params[0] eq '--debug_result') {
            shift @proc_params;
            $debug_result = 1;
            
        }
        elsif ($proc_params[1] eq '--debug_result') {
            pop @proc_params;
            $debug_result = 1;
        }
        else {
            $error = 1;
        }
    }
    
    if ($expects_return and $debug_result) {
        $state->push_script_return($result_name, $result_type, 1);
    }
    elsif ($expects_return) {
        $state->push_script_return($result_name, $result_type, 0);
    }
    elsif ($debug_result) {
        $expects_return = 1;
        $state->push_script_return('', '', 1);
    }
    
    if ((@proc_params != 1) or ((@proc_params == 1) and ($proc_params[0] !~ /^"[^"]+"$/))) {
        $error = 1;
    }
    
    if ($error) {
        $state->report_error("run_script requires a single string argument containing the path to the script to run, and allows an optional result.");
        print "  Command format:\n\n";
        print "  run_script \"string\" [ --debug_result ] => optional_result_name\n    param 1: filename of script to run\n\n";
        
        return -1;
    }

    my $filename = $proc_params[0];
    $filename =~ s/\"//g;
    
    $state->in_script();
    my $ret = $state->process_script($filename, $expects_return);
    $state->off_script();
    
    return $ret;
}

1;
