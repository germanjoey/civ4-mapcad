package Civ4MapCad::Commands::List;
 
use strict;
use warnings;
 
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(list_shapes list_groups list_layers list_masks list_weights show_weights
                    dump_mask_to_console dump_group dump_mask dump_layer);
 
use Config::General;

use Civ4MapCad::ParamParser;
use Civ4MapCad::Util qw(deepcopy slurp);
use Civ4MapCad::Dump qw(dump_out dump_framework dump_single_layer);
 
sub list_shapes {
    my ($state, @params) = @_;
   
    $state->list( sort keys %{$state->{'shape'}} );
    return 1;
}
 
sub list_groups {
    my ($state, @params) = @_;
   
    $state->list( sort keys %{$state->{'group'}} );
    return 1;
}
 
sub list_layers {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group']
    });
    return -1 if $pparams->has_error;
    
    my ($group) = $pparams->get_required();
    $state->list( $group->get_layer_names() );
    
    return 1;
}
 
sub list_masks {
    my ($state, @params) = @_;
   
    $state->list( sort keys %{$state->{'mask'}} );
    return 1;
}
 
sub list_weights {
    my ($state, @params) = @_;
   
    $state->list(sort keys %{$state->{'weight'}} );
    return 1;
}
 
sub show_weights {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['weight'],
        'optional' => {
            'flatten' => 0
        }
    });
    return -1 if $pparams->has_error;
    
    my ($weight) = $pparams->get_required();
    my $flatten = $pparams->get_named('flatten');
    
    my @to_show;
    
    if ($flatten) {
        @to_show = map { "$_->[0] $_->[1] => $_->[2]," } ( $weight->flatten($state, 1) );
    }
    else {
        @to_show = map { "$_->[0] $_->[1] => $_->[2]," } (@{ $weight->{'pairs'} });
    }
    
    $to_show[-1] =~ s/,$//;
    $state->list( @to_show );
    
    return 1;
}

sub dump_mask_to_console {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['mask']
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

sub dump_mask {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['mask'],
        'optional' => {
            'add_to_existing' => 0
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

sub dump_group {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'optional' => {
            'info' => 0,
            'add_to_existing' => 0
        }
    });
    return -1 if $pparams->has_error;
    
    my ($group) = $pparams->get_required();
    my $copy = deepcopy($group);
    
    my $do_info = $pparams->get_named('info');
    
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

sub dump_layer {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer'],
        'optional' => {
            'info' => 0,
            'add_to_existing' => 0
        }
    });
    return -1 if $pparams->has_error;
    
    my ($layer) = $pparams->get_required();
    my $do_info = $pparams->get_named('info');
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