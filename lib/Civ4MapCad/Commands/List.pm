package Civ4MapCad::Commands::List;
 
use strict;
use warnings;
 
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(list_shapes list_groups list_layers list_masks list_weights list_terrain 
                    show_weights dump_mask_to_console dump_group dump_mask dump_layer);
 
use Config::General;

use Civ4MapCad::ParamParser;
use Civ4MapCad::Util qw(deepcopy slurp);
use Civ4MapCad::Dump qw(dump_out dump_framework dump_single_layer);
 
sub list_shapes {
    my ($state, @params) = @_;
    
    my @shapes = sort keys %{$state->{'shape'}};
    if (@params == 1) {
        @shapes = grep { $_ =~ /$params[0]/ } @shapes;
    }
   
    $state->list( @shapes );
    return 1;
}
 
sub list_groups {
    my ($state, @params) = @_;
   
    my @groups = sort keys %{$state->{'group'}};
    if (@params == 1) {
        @groups = grep { $_ =~ /$params[0]/ } @groups;
    }
    
    $state->list( @groups );
    return 1;
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
    
    my ($group) = $pparams->get_required();
    
    my @layers = map { sprintf "%2d %s", $group->get_layer_priority($_), $_ } ($group->get_layer_names());
    
    $state->list( @layers );
    
    return 1;
}
 
sub list_masks {
    my ($state, @params) = @_;
   
    my @masks = sort keys %{$state->{'mask'}};
    if (@params == 1) {
        @masks = grep { $_ =~ /$params[0]/ } @masks;
    }
    
    $state->list( @masks );
    return 1;
}

sub list_terrain {
    my ($state, @params) = @_;
   
    my @terrains = sort keys %{$state->{'terrain'}};
    if (@params == 1) {
        @terrains = grep { $_ =~ /$params[0]/ } @terrains;
    }
    $state->list( @terrains );
    return 1;
}

sub list_weights {
    my ($state, @params) = @_;
   
    my @weights = sort keys %{$state->{'weight'}};
    if (@params == 1) {
        @weights = grep { $_ =~ /$params[0]/ } @weights;
    }
    $state->list( @weights );
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
    
    my ($weight) = $pparams->get_required();
    my $flatten = $pparams->get_named('flatten');
    
    my @to_show;
    
    if ($flatten) {
        @to_show = map { "$_->[0] $_->[1] => $_->[2]," } ( $weight->flatten(1) );
    }
    else {
        @to_show = map { "$_->[0] $_->[1] => $_->[2]," } (@{ $weight->{'pairs'} });
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
    my ($mask) = $pparams->get_required();
    
    print "\n";
    foreach my $xx (0..$mask->get_width()-1) {
        foreach my $yy (0..$mask->get_height()-1) {
            my $x = $mask->get_width() - 1 - $xx;
            my $y = $mask->get_height() - 1 - $yy;
            my $value = ($mask->{'canvas'}[$x][$y] > 0) ? 1 : ' ';
            print $value;
        }
        print "\n";
    }
    print "\n";
}

my $dump_mask_help_text = qq[
    Displays a mask into the dump.html debugging window. Mask values closer to zero will appear blue, while those closer to 1 will appear red. If 'add_to_existing' is specified, the dump will appear as a new tab in the existing dump.html.
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
    
    my ($mask) = $pparams->get_required();
    my ($mask_name) = $pparams->get_required_names();
    
    my $add_to_existing = $pparams->get_named("add_to_existing");
    my $template = ($add_to_existing) ? 'dump.html' : 'def/dump.html.tmpl';
    my $start_index = ($add_to_existing) ? (_find_max_tab($template)+1) : 0;
    
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
            my $cell = qq[<a title="$title"><img src="doc/icons/none.png" /></a>];
            push @row, qq[<td class="tooltip" style="background-color: $c;">$cell</td>];
        }
        
        push @cells, \@row;
    }
    
    dump_framework($template, 'dump.html', $mask_name, $start_index, [[$mask_name, [], \@cells]])
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
    
    my ($group) = $pparams->get_required();
    my $copy = deepcopy($group);
    
    # TODO
    my $do_info = $pparams->get_named('info_too');
    
    my @layer_cells;
    foreach my $layer ($copy->get_layers()) {
        $layer->fix_coast();
        push @layer_cells, dump_single_layer($layer, $do_info);
    }
    
    my $add_to_existing = $pparams->get_named("add_to_existing");
    my $template = ($add_to_existing) ? 'dump.html' : 'def/dump.html.tmpl';
    my $start_index = ($add_to_existing) ? (_find_max_tab($template)+1) : 0;
    
    dump_framework($template, 'dump.html', $group->get_name(), $start_index, \@layer_cells);
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
    
    my ($layer) = $pparams->get_required();
    my $do_info = $pparams->get_named('info_too');
    my $copy = deepcopy($layer);
    $copy->fix_coasts();
    
    my $add_to_existing = $pparams->get_named("add_to_existing");
    my $template = ($add_to_existing) ? 'dump.html' : 'def/dump.html.tmpl';
    my $start_index = ($add_to_existing) ? (_find_max_tab($template)+1) : 0;

    my $cells = dump_single_layer($copy, $do_info);
    dump_framework($template, 'dump.html', $layer->get_name(), $start_index, [$cells]);
}

sub _find_max_tab {
    my ($template_filename) = @_;
    
    my ($template) = slurp($template_filename);
    
    my @tabs = $template =~ /id="tabs-(\d+)"/g;
    @tabs = sort {$b <=> $a} @tabs;
    return $tabs[0];
}

1;