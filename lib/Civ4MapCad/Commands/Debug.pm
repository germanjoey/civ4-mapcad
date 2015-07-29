package Civ4MapCad::Commands::Debug;
 
use strict;
use warnings;
 
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(dump_mask_to_console dump_group dump_mask dump_layer evaluate_weight evaluate_weight_inverse show_weights);

use Civ4MapCad::ParamParser;
use Civ4MapCad::Util qw(deepcopy slurp);
use Civ4MapCad::Dump qw(dump_out dump_framework dump_single_layer);

use Civ4MapCad::Commands::List qw(_describe_terrain);

my $evaluate_weight_help_text = qq[
   Evaluates the result of a weight table with an arbitrary floating point value between 0 and 1, e.g. as if that
   value were the coordinate 'evaluate_weight' is only intended to be a debugging command; please see the
   Mask-related commands, e.g. 'generate_layer_from_mask', 'modify_layer_from_mask', for actually using weights
   to generate/modify tiles. 
];
sub evaluate_weight {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['weight', 'float'],
        'required_descriptions' => ['weight', 'value to evaluate'],
        'help_text' => $evaluate_weight_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($weight, $value) = $pparams->get_required();
    my ($terrain_name, $terrain) = $weight->evaluate($value);
    $weight->deflate();
    
    my @full;
    if (defined($terrain_name)) {
        @full = ($terrain_name, _describe_terrain($terrain));
    }
    else {
        @full = ('Evaluated to nothing.');
    }
    
    $state->list(@full);
    
    return 1;
}

my $evaluate_weight_inverse_help_text = qq[
   Evaluates the inverse result of a weight table with an terrain in order to get the corresponding value, e.g. 
   as if this terrain were at the coordinates of a layer tile. 'evaluate_weight_inverse' is only intended to be
   a debugging command; please see the Mask-related commands, e.g. 'generate_layer_from_mask', 'modify_layer_from_mask',
   for actually using weights to generate/modify tiles. 
];
sub evaluate_weight_inverse {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['weight', 'terrain'],
        'required_descriptions' => ['weight', 'terrain to evaluate'],
        'help_text' => $evaluate_weight_inverse_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($weight, $terrain) = $pparams->get_required();
    
    my $tile = Civ4MapCad::Map::Tile->new_default(0, 0);
    $tile->set_tile($terrain);
    my ($value) = $weight->evaluate_inverse($tile);
    $weight->deflate();
    
    my @full;
    if (defined($value)) {
        $state->list( $value );
    }
    else {
        $state->list( 'Evaluated to nothing.' );
    }
    
    return 1;
}

my $show_weights_help_text = qq[
    Shows the definition for a weight. The optional 'flatten' arguments determines whether nested weights are expanded or not. (off by default)
];
sub show_weights {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['weight'],
        'required_descriptions' => ['weight to describe'],
        'help_text' => $show_weights_help_text,
        'optional' => {
            'flatten' => 'false'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($weight) = $pparams->get_required();
    my $flatten = $pparams->get_named('flatten');
    
    my @to_show;
    
    if ($flatten) {
        @to_show = map { sprintf "$_->[0] %6.4f => $_->[2],", $_->[1] } ( $weight->flatten(1) );
    }
    else {
        @to_show = map { sprintf "%s %6.4f => %s,", @$_ } (@{ $weight->{'pairs'} });
    }
    
    $to_show[-1] =~ s/,$//;
    $state->list( @to_show );
    return 1;
}
 
my $dump_mask_to_console_help_text = qq[
    Dump a mask as ascii-art for quick debugging.
];
sub dump_mask_to_console {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['mask'],
        'required_descriptions' => ['mask to dump'],
        'help_text' => $dump_mask_to_console_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    $state->buffer_bar();
    
    my ($mask) = $pparams->get_required();
    
    my @lines;
    foreach my $xx (0..$mask->get_width()-1) {
        my $line = '';
        foreach my $yy (0..$mask->get_height()-1) {
            my $x = $mask->get_width() - 1 - $xx;
            my $y = $mask->get_height() - 1 - $yy;
            my $value = ($mask->{'canvas'}[$x][$y] > 0) ? 1 : ' ';
            $line .= $value;
        }
        
        push @lines, $line;
    }
    
    $state->list( @lines );
    return 1;
}

my $dump_mask_help_text = qq[
    Displays a mask into the dump.html debugging window. Mask values closer to zero will appear blue, while those closer to 1 will appear red. If 'add_to_existing'
    is specified, the dump will appear as a new tab in the existing dump.html.
];
sub dump_mask {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['mask'],
        'required_descriptions' => ['mask to dump'],
        'help_text' => $dump_mask_help_text,
        'optional' => {
            'add_to_existing' => 'false'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($mask) = $pparams->get_required();
    my ($mask_name) = $pparams->get_required_names();
    my $add_to_existing = $pparams->get_named("add_to_existing");
    
    my $template;
    my $set_index;
    my $start_index;
    if ($add_to_existing) {
        $template = 'dump.html';
        $start_index = _find_max_tab($template)+1;
        $set_index = _find_max_set($template)+1;
    }
    else {
        $template = 'debug/dump.html.tmpl';
        $set_index = 1;
        $start_index = 0;
    }
    
    my $canvas = $mask->{'canvas'};
    my $maxrow = $#$canvas;
    my $maxcol = $#{ $canvas->[0] };
    
    my @cells;
    foreach my $y (reverse(0..$maxcol)) {
    
        my @row;
        foreach my $x (0..$maxrow) {
            my $value = $canvas->[$x][$y];
            my $c = sprintf '#%02x00%02x', $value*255, 255-$value*255;
            
            my $title = "$x, $y: $value";
            my $cell = qq[<a title="$title"><img src="debug/icons/none.png" /></a>];
            push @row, qq[<td class="tooltip"><div style="background-color: $c;">$cell</div></td>];
        }
        
        push @cells, \@row;
    }
    
    dump_framework($template, 'dump.html', $mask_name, $start_index, [["$set_index: " . $mask_name, [], \@cells]]);
    return 1;
}

my $dump_group_help_text = qq[
    Displays a group in the dump.html debugging window. Each layer will appear as its own tab. If 'add_to_existing' is specified, the dump will add additional tabs to the existing dump.html. If '--info_too' is specified, all per-layer map information will be specified in a table.
];
sub dump_group {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to dump'],
        'help_text' => $dump_group_help_text,
        'optional' => {
            'info_too' => 'false',
            'add_to_existing' => 'false'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($group) = $pparams->get_required();
    my $do_info = $pparams->get_named('info_too');
    my $add_to_existing = $pparams->get_named("add_to_existing");
    
    my $template;
    my $set_index;
    my $start_index;
    if ($add_to_existing) {
        $template = 'dump.html';
        $start_index = _find_max_tab($template) + 1;
        $set_index = _find_max_set($template) + 1;
    }
    else {
        $template = 'debug/dump.html.tmpl';
        $set_index = 1;
        $start_index = 0;
    }
    
    my $copy = deepcopy($group);
    
    my @layer_cells;
    foreach my $layer ($copy->get_layers()) {
        $layer->fix_coast();
        my $full_name = '$' . $layer->get_group->get_name() . '.' . $layer->get_name();
        push @layer_cells, dump_single_layer($layer, "$set_index: $full_name", $do_info);
    }
    
    dump_framework($template, 'dump.html', '$' . $group->get_name(), $start_index, \@layer_cells);
    return 1;
}

my $dump_layer_help_text = qq[
    Displays a single layer in the dump.html debugging window. If 'add_to_existing' is specified, the dump will add additional tabs to the existing dump.html. If '--info_too' is specified, all per-layer map information will be specified in a table.
];
sub dump_layer {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer'],
        'required_descriptions' => ['layer to dump'],
        'help_text' => $dump_layer_help_text,
        'optional' => {
            'info_too' => 'false',
            'add_to_existing' => 'false'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($layer) = $pparams->get_required();
    my $do_info = $pparams->get_named('info_too');
    my $add_to_existing = $pparams->get_named("add_to_existing");
    
    my $template;
    my $set_index;
    my $start_index;
    if ($add_to_existing) {
        $template = 'dump.html';
        $start_index = _find_max_tab($template)+1;
        $set_index = _find_max_set($template)+1;
    }
    else {
        $template = 'debug/dump.html.tmpl';
        $set_index = 1;
        $start_index = 0;
    }
    
    my $copy = deepcopy($layer);
    $copy->fix_coast();
    
    my $full_name = '$' . $layer->get_group->get_name() . '.' . $layer->get_name();
    my $cells = dump_single_layer($copy, "$set_index: $full_name", $do_info);
    dump_framework($template, 'dump.html', $full_name, $start_index, [$cells]);
    return 1;
}

sub _find_max_tab {
    my ($template_filename) = @_;
    
    my ($template) = slurp($template_filename);
    
    my @tabs = $template =~ /id="tabs-(\d+)"/g;
    @tabs = sort {$b <=> $a} @tabs;
    return $tabs[0];
}

sub _find_max_set {
    my ($template_filename) = @_;
    
    my ($template) = slurp($template_filename);
    my @sets = $template =~ /a href=\"\#tabs-\d+\">(\d+):/g;
    @sets = sort {$b <=> $a} @sets;
    return $sets[0];
}
