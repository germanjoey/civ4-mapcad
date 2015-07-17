package Civ4MapCad::Commands::List;
 
use strict;
use warnings;
 
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(list_shapes list_groups list_layers list_masks list_weights list_terrain 
                    show_weights dump_mask_to_console dump_group dump_mask dump_layer evaluate_weight);
 
use Config::General;

use Civ4MapCad::ParamParser;
use Civ4MapCad::Util qw(deepcopy slurp);
use Civ4MapCad::Dump qw(dump_out dump_framework dump_single_layer);
 
my $list_shapes_help_text = qq[
  Command Format: 
  
    list_shapes search_term

  The search_term is optional; if not supplied, all shapes will be listed.
];
sub list_shapes {
    my ($state, @params) = @_;
    
    if ((@params == 1) and ($params[0] eq '--help')) {
        $state->buffer_bar();
        print $list_shapes_help_text, "\n";
        $state->register_print();
        return 1;
    }
    
    my @shape_names = sort keys %{$state->{'shape'}};
    if (@params == 1) {
        @shape_names = grep { $_ =~ /\Q$params[0]\E/ } @shape_names;
    }
    elsif (@params > 0) {
        $state->buffer_bar();
        print $list_shapes_help_text, "\n";
        $state->register_print();
        return -1;
    }
    
    my @full;
    foreach my $shape_name (@shape_names) {
        my $description = $shape_name;
    
        foreach my $param (keys %{ $state->{'shape_param'}{$shape_name} }) { 
            if ($state->{'shape_param'}{$shape_name}{$param} =~ /\-?\d+\.\d+/) {
                $description .= " --$param float";
            }
            else {
                $description .= " --$param int";
            }
        }
        
        push @full, $description
    }
    
    if (@full == 0) {
        @full = ("None found.");
        @full = ("None found matching description '$params[0]'.") if @params == 1;
    }
   
    $state->list( @full );
    return 1;
}

my $list_groups_help_text = qq[
  Command Format: 
  
    list_groups search_term

  The search_term is optional; if not supplied, all groups will be listed.
];
sub list_groups {
    my ($state, @params) = @_;
   
    if ((@params == 1) and ($params[0] eq '--help')) {
        $state->buffer_bar();
        print $list_groups_help_text, "\n";
        $state->register_print();
        return 1;
    }
    
    my @group_names = sort keys %{$state->{'group'}};
    if (@params == 1) {
        @group_names = grep { $_ =~ /\Q$params[0]\E/ } @group_names;
    }
    elsif (@params > 0) {
        $state->buffer_bar();
        print $list_groups_help_text, "\n";
        $state->register_print();
        return -1;
    }
    
    my @full;
    foreach my $group_name (@group_names) {
        my $group = $state->{'group'}{$group_name};
        my $description = _group_description($group);
        push @full, $description;
    }
    
    if (@full == 0) {
        @full = ("None found.");
        @full = ("None found matching description '$params[0]'.") if @params == 1;
    }
    
    $state->list( @full );
    return 1;
}

sub _group_description {
    my ($group) = @_;

    my $description = '$' . $group->get_name() . " (size: " . $group->get_width() . ' x ' . $group->get_height() . ")";
    $description .= ', ' if $group->wrapsX() or $group->wrapsY();
    $description .= 'wraps in X' if $group->wrapsX();
    $description .= ' and ' if $group->wrapsX() and $group->wrapsY();
    $description .= 'wraps in Y' if $group->wrapsY();
    
    return $description;
}
 
my $list_layers_help_text = qq[
    Lists all layers of a group by priority.
];
sub list_layers {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'help_text' => $list_layers_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($group) = $pparams->get_required();
    my $group_description = _group_description($group);
    
    my @layers;
    push @layers, "$group_description\n";
    push @layers, "Layers:\n";
    
    foreach my $layer ($group->get_layers()) {
        my $layer_name = $layer->get_name();
        my $priority = 1 + $group->{'max_priority'} - $group->get_layer_priority($layer_name);
        my $moved = sprintf "moved to %d,%d from group origin", $layer->get_offsetX(), $layer->get_offsetY();
        $moved = "aligned with group origin" if ($layer->get_offsetX() == 0) and ($layer->get_offsetY() == 0);
        my $description = sprintf "  priority %s, %s (size: %d x %d), $moved", $priority, $layer->get_name(), $layer->get_width(), $layer->get_height();
        push @layers, $description;
    }
    
    push @layers, "\n  (higher priority numbers means those layers are \"above\" the others).";
    
    $state->list( @layers );
    return 1;
}

my $list_masks_help_text = qq[
  Command Format: 
  
    list_masks search_term

  The search_term is optional; if not supplied, all masks will be listed.
];
sub list_masks {
    my ($state, @params) = @_;
   
    if ((@params == 1) and ($params[0] eq '--help')) {
        $state->buffer_bar();
        print $list_masks_help_text, "\n";
        $state->register_print();
        return 1;
    }
    
    my @mask_names = sort keys %{$state->{'mask'}};
    if (@params == 1) {
        @mask_names = grep { $_ =~ /\Q$params[0]\E/ } @mask_names;
    }
    elsif (@params > 0) {
        $state->buffer_bar();
        print $list_masks_help_text, "\n";
        $state->register_print();
        return -1;
    }
    
    my @full;
    foreach my $mask_name (@mask_names) {
        my $mask = $state->{'mask'}{$mask_name};
        my $description = sprintf "%s (size: %d x %d)", $mask_name, $mask->get_width(), $mask->get_height();
        push @full, $description;
    }
    
    if (@full == 0) {
        @full = ("None found.");
        @full = ("None found matching description '$params[0]'.") if @params == 1;
    }
    
    $state->list( @full );
    return 1;
}

my $list_terrain_help_text = qq[
  Command Format: 
  
    list_terrain search_term

  The search_term is optional; if not supplied, all terrain will be listed.
];
sub list_terrain {
    my ($state, @params) = @_;
   
    if ((@params == 1) and ($params[0] eq '--help')) {
        $state->buffer_bar();
        print $list_terrain_help_text, "\n";
        $state->register_print();
        return 1;
    }
    
    my @terrain_names = sort keys %{$state->{'terrain'}};
    if (@params == 1) {
        @terrain_names = grep { $_ =~ /\Q$params[0]\E/ } @terrain_names;
        
        my @full;
        foreach my $terrain_name (@terrain_names) {
            push @full, $terrain_name;
            push @full, _describe_terrain($state->{'terrain'}{$terrain_name});
            $full[-1] .= "\n";
        }
        
        chomp $full[$#full] if @full > 0;
        @terrain_names = @full;
    }
    elsif (@params > 0) {
        $state->buffer_bar();
        print $list_terrain_help_text, "\n";
        $state->register_print();
        return -1;
    }
    
    if (@terrain_names == 0) {
        @terrain_names = ("None found.");
        @terrain_names = ("None found matching description '$params[0]'.") if @params == 1;
    }
    
    $state->list( @terrain_names );
    return 1;
}

sub _describe_terrain {
    my ($terrain) = @_;
    my @height_types = ('Peak', 'Hill', 'Flat', 'Water');
        
    my @full;
    foreach my $key (sort keys %$terrain) {
        push @full, "  $key = $terrain->{$key}";
        
        if ($key eq 'PlotType') {
            my $height = $terrain->{$key} + 0;
            $full[-1] .= " ($height_types[$height])";
        }
    }
    
    return @full;
}

my $evaluate_weight_help_text = "
   The 'evaluate_weight' command returns the result of a Weight Table were it to be evaluated with a floating point value,
   as if that value were the coordinate of a mask. Thus, that value needs to be between 0 and 1. 'evaluate_weight' is only
   intended to be a debugging command; please see the Mask-related commands, e.g. 'generate_layer_from_mask',
   'modify_layer_from_mask', for actually using weights to generate/modify tiles. 
";
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
    
    my @full = ($terrain_name);
    push @full, _describe_terrain($terrain);
    
    $state->list(@full);
    $weight->deflate();
    
    return 1;
}

my $list_weights_help_text = qq[
  Command Format: 
  
    list_weights search_term

  The search_term is optional; if not supplied, all weights will be listed.
];
sub list_weights {
    my ($state, @params) = @_;
   
    if ((@params == 1) and ($params[0] eq '--help')) {
        $state->buffer_bar();
        print $list_weights_help_text, "\n";
        $state->register_print();
        return 1;
    }
    
    my @weight_names = sort keys %{$state->{'weight'}};
    if (@params == 1) {
        @weight_names = grep { $_ =~ /\Q$params[0]\E/ } @weight_names;
    }
    elsif (@params > 0) {
        $state->buffer_bar();
        print $list_weights_help_text, "\n";
        $state->register_print();
        return -1;
    }
    
    my @full;
    foreach my $weight_name (@weight_names) {
        my $weight = $state->{'weight'}{$weight_name};
        my @packed = @{ $weight->{'pairs'} };
        my @flat = $weight->flatten(1);
        
        my $description;
        if (@packed == @flat) {
            $description = sprintf "%s, %d entries", $weight_name, @packed+0;
        }
        else {
            $description = sprintf "%s, %d entries packed, %d entries flat", $weight_name, @packed+0, @flat+0;
        }
        
        push @full, $description;
    }
    
    if (@full == 0) {
        @full = ("None found.");
        @full = ("None found matching description '$params[0]'.") if @params == 1;
    }
    
    $state->list( @full );
    return 1;
}

my $show_weights_help_text = qq[
    Shows the definition for a weight. The optional 'flatten' arguments determines whether nested weights are expanded or not. (off by default)
];
sub show_weights {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['weight'],
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

1;