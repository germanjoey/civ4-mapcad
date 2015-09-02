package Civ4MapCad::Commands::Debug;
 
use strict;
use warnings;
 
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(debug_mask_in_console debug_group debug_mask debug_layer debug_weight evaluate_weight evaluate_weight_inverse show_weights);

use List::Util qw(min max);
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
   for actually using weights to generate/modify tiles. If '--exact_match' is set, then all fields of the terrain
   must match all fields of the tile (except rivers), and vice versa.
];
sub evaluate_weight_inverse {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['weight', 'terrain'],
        'required_descriptions' => ['weight', 'terrain to evaluate'],
        'help_text' => $evaluate_weight_inverse_help_text,
        'optional' => {
            'exact_match' => 'false'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $exact_match = $pparams->get_named('exact_match');
    my ($weight, $terrain) = $pparams->get_required();
    
    my $tile = Civ4MapCad::Map::Tile->new_default(0, 0);
    $tile->set_tile($terrain);
    my ($value) = $weight->evaluate_inverse($tile, $exact_match);
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

my $debug_weight_help_text = qq[
    Shows the definition for a weight. The optional 'flatten' arguments determines whether nested weights are expanded or not. (off by default)
];
sub debug_weight {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['weight'],
        'required_descriptions' => ['weight to describe'],
        'help_text' => $show_weights_help_text,
        'optional' => {
            'flatten' => 'false',
            'add_to_existing' => 'false'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($weight) = $pparams->get_required();
    my ($weight_name) = $pparams->get_required_names();
    my $add_to_existing = $pparams->get_named("add_to_existing");
    my $flatten = $pparams->get_named('flatten');
    
    my $template;
    my $set_index;
    my $start_index;
    if ($add_to_existing) {
        $template = 'debug.html';
        $start_index = _find_max_tab($template)+1;
        $set_index = _find_max_set($template)+1;
    }
    else {
        $template = 'debug/debug.html.tmpl';
        $set_index = 1;
        $start_index = 0;
    }
    
    my @to_show;
    if ($flatten) {
        @to_show = map { sprintf "$_->[0] %6.4f => $_->[2],", $_->[1] } ( $weight->flatten(1) );
    }
    else {
        @to_show = map { sprintf "%s %6.4f => %s,", @$_ } (@{ $weight->{'pairs'} });
    }
    $to_show[-1] =~ s/,$//;
    
    my $head = qq[<li><a href="#tabs-$start_index">$set_index: $weight_name</a></li>];
    my $body = qq[<div class="map_tab" id="tabs-$start_index"><code><pre>\n];
    $body .= "new_weight_table ";
    $body .= join("\n                 ", @to_show);
    $body .= "\n                 => $weight_name";
    $body .= '</pre></code></div>';
    dump_out ($template, 'debug.html', $weight_name, $head, $body, '', '');
    
    return 1;
}
 
my $debug_mask_in_console_help_text = qq[
    Debug a mask as ascii-art in the console for quick debugging.
];
sub debug_mask_in_console {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['mask'],
        'required_descriptions' => ['mask to debug'],
        'help_text' => $debug_mask_in_console_help_text
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

my $debug_mask_help_text = qq[
    Displays a mask into the debug.html debugging window. Mask values closer to zero will appear blue, while those closer to 1 will appear red. If 'add_to_existing'
    is specified, the debug will appear as a new tab in the existing debug.html.
];
sub debug_mask {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['mask'],
        'required_descriptions' => ['mask to debug'],
        'help_text' => $debug_mask_help_text,
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
        $template = 'debug.html';
        $start_index = _find_max_tab($template)+1;
        $set_index = _find_max_set($template)+1;
    }
    else {
        $template = 'debug/debug.html.tmpl';
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
            my $v = min(1, max(0, $value));
            my $c = sprintf 'p%02x%02x', 16*int($v*15)+8, 16*int(15 - $v*15)+8;
            
            my $title = "$x, $y: $value";
            my $cell = qq[<a title="$title"><img src="i/none.png"/></a>];
            push @row, qq[<td><div class="$c">$cell</div></td>];
        }
        
        push @cells, \@row;
    }
    
    dump_framework($template, 'debug.html', $mask_name, $start_index, [["$set_index: " . $mask_name, [], \@cells]], '', '');
    return 1;
}

my $debug_group_help_text = qq[
    Displays a group in the debug.html debugging window. Each layer will appear as its own tab. If 'add_to_existing' is specified, the debug window will add additional tabs to the existing debug.html. 
];
sub debug_group {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to debug'],
        'help_text' => $debug_group_help_text,
        'optional' => {
            'add_to_existing' => 'false',
            'alloc_file' => ''
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($group) = $pparams->get_required();
    my $add_to_existing = $pparams->get_named("add_to_existing");
    my $alloc_file = $pparams->get_named("alloc_file");
    my $alloc;
    
    if (($alloc_file ne '') and ($add_to_existing == 1)) {
        $state->report_warning("It's recommended that you do not add an alloc_file to a group debug in conjunction with --add_to_existing, as it can cause errors. (and will also be really slow)");
    }
    
    my $has_alloc = 0;
    my $balance_report = '';
    if ($alloc_file ne '') {
        if ($group->count_layers() != 1) {
            $state->report_error("Can only use an alloc file on flat layers.");
            return -1;
        }
        
        my $max_x = 0;
        my $max_y = 0;
        ($alloc, $max_x, $max_y) = _read_alloc_file($alloc_file);
        $balance_report = _read_balance_report($alloc_file);
        
        if (! defined $alloc) {
            $state->report_error("Error reading from $alloc_file.");
            return -1;
        }
        
        if ((($max_x+1) != $group->get_width()) or (($max_y+1) != $group->get_height())) {
            $state->report_error("Dimensions of alloc file do not match the group.");
            return -1;
        }
        $has_alloc = 1;
    }
    
    my $template;
    my $set_index;
    my $start_index;
    if ($add_to_existing) {
        $template = 'debug.html';
        $start_index = _find_max_tab($template) + 1;
        $set_index = _find_max_set($template) + 1;
    }
    else {
        $template = 'debug/debug.html.tmpl';
        $set_index = 1;
        $start_index = 0;
    }
    
    my $copy = deepcopy($group);
    
    my @layer_cells;
    my $alloc_css = '';
    foreach my $layer ($copy->get_layers()) {
        $layer->fix_coast();
        my $full_name = '$' . $layer->get_group->get_name() . '.' . $layer->get_name();
        
        $state->{'current_debug'} = $layer; # so that we can get player info from the perspective of the tile
        $alloc_css = _dump_alloc_css($state, $layer) if $has_alloc; # need to do this here so we can access the layer
        push @layer_cells, dump_single_layer($layer, "$set_index: $full_name", $alloc);
        delete $state->{'current_debug'};
    }
    
    dump_framework($template, 'debug.html', '$' . $group->get_name(), $start_index, \@layer_cells, $alloc_css, $balance_report);
    return 1;
}

my $debug_layer_help_text = qq[
    Displays a single layer in the debug.html debugging window. If 'add_to_existing' is specified, the debug window will add additional tabs to the existing debug.html.
];
sub debug_layer {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer'],
        'required_descriptions' => ['layer to debug'],
        'help_text' => $debug_layer_help_text,
        'optional' => {
            'add_to_existing' => 'false',
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($layer) = $pparams->get_required();
    my $add_to_existing = $pparams->get_named("add_to_existing");
    
    my $template;
    my $set_index;
    my $start_index;
    if ($add_to_existing) {
        $template = 'debug.html';
        $start_index = _find_max_tab($template)+1;
        $set_index = _find_max_set($template)+1;
    }
    else {
        $template = 'debug/debug.html.tmpl';
        $set_index = 1;
        $start_index = 0;
    }
    
    my $copy = deepcopy($layer);
    $copy->fix_coast();
    $state->{'current_debug'} = $layer; # so that we can get player info from the perspective of the tile
    
    my $full_name = '$' . $layer->get_group->get_name() . '.' . $layer->get_name();
    my $cells = dump_single_layer($copy, "$set_index: $full_name");
    dump_framework($template, 'debug.html', $full_name, $start_index, [$cells], '', '');
    
    delete $state->{'current_debug'};
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

sub _read_alloc_file {
    my ($filename) = @_;
    return if $filename eq '';
    
    my %alloc;
    open (my $ain, $filename) or return;
    
    my $max_x = 0;
    my $max_y = 0;
    while (1) {
        my $line = <$ain>;
        last unless defined $line;
        next unless $line =~ /\d/;
        next if $line =~ /\s*\#/;
        chomp $line;
        my ($x, $y, $civ, $v) = split ' ', $line;
        $alloc{$x}{$y}{$civ} = $v;
        $max_x = $x if $x > $max_x;
        $max_y = $y if $y > $max_y;
    }
    
    return (\%alloc, $max_x, $max_y);
}

sub _read_balance_report {
    my ($filename) = @_;
    return if $filename eq '';
    
    $filename =~ s/\.alloc//;
    
    my $base_filename = "$filename";
    $base_filename =~ s/^(?:\w+\/)+//;
    
    my $balance_report = slurp("$filename.balance_report.txt");
    $balance_report = qq[<h2>Balance Report:</h2><textarea class="lined">$balance_report</textarea><a href="$base_filename.CivBeyondSwordWBSave">Save File</a>];
    return $balance_report;
}

sub _dump_alloc_css {
    my ($state, $layer) = @_;
    
    my $alloc_css = '';
    
    my $tmpl = qq[
        content: " " !important;
        display: block !important;
        position: absolute !important;
        pointer-events: none !important;
        height: 100% !important;
        top: 0 !important;
        left: 0 !important;
        right: 0 !important;
    ];
    
    my $i = 0;
    my $players = $layer->{'map'}{'Players'};
    foreach my $player (@$players) {
        my $player_color = $player->{'Color'};
        next if $player_color =~ /none/i;
        
        $player_color =~ s/^PLAYERCOLOR_//;
        $player_color = 'COLOR_PLAYER_' . $player_color;
    
        $alloc_css .= "    .c$i {\n";
        $alloc_css .= "        background-color: $state->{'data'}{'colorcodes'}{$player_color}{'hex'} !important;$tmpl";
        $alloc_css .= "}\n\n";
        $i++;
    }
    
    return $alloc_css;
}