package Civ4MapCad::Dump;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(dump_out dump_framework dump_single_layer);

use Civ4MapCad::Util qw(slurp);

sub dump_framework {
    my ($template_filename, $dump_filename, $full_name, $start_index, $tabs, $alloc_css) = @_;
    
    my @tab_heads; my @tab_bodies;
    
    foreach my $t (0..$#$tabs) {
        my ($name, $info, $rows) = @{ $tabs->[$t] };
        
        my $id = $t + $start_index;
        my $head = qq[<li><a href="#tabs-$id">$name</a></li>];
        
        my $body = qq[<div class="map_tab" id="tabs-$id">\n];
        
        if (@$info > 0) {
            $body .= $info->[0];
            $body .= "\n";
        }
        
        $body .= "    <table>\n";
        foreach my $row (@$rows) {
            $body .= "        <tr>\n";
            foreach my $cell (@$row) {
                $body .= "            $cell\n";
            }
            $body .= "        </tr>\n";
        }
        $body .= "    </table>\n";
        
        $body .= "</div>\n";
        
        push @tab_heads, $head;
        push @tab_bodies, $body;
    }
    
    my $head = '';
    foreach my $th (@tab_heads) {
        $head .= "  $th\n";
    }
    
    my $body = '';
    foreach my $tb (@tab_bodies) {
        $body .= $tb;
    }
    
    dump_out($template_filename, $dump_filename, $full_name, $head, $body, $alloc_css);
}

sub dump_out {
    my ($template_filename, $dump_filename, $name, $head, $body, $alloc_css) = @_;
    
    $head =~ s/\n/\n    /g;
    $body =~ s/\n/\n    /g;
    $head .= "\n		<!-- \$\$\$\$HEAD\$\$\$\$ -->\n";
    $body .= "\n		<!-- \$\$\$\$BODY\$\$\$\$ -->\n";
    
    $alloc_css = "<style>\n" . $alloc_css . "\n    </style>\n";
    
    my ($template) = slurp($template_filename);
    $template =~ s/\<!-- \$\$\$\$CIVSTYLE\$\$\$\$ -->/$alloc_css/;
    $template =~ s/\<!--\s+\$\$\$\$HEAD\$\$\$\$\s+\-\-\>/$head/;
    $template =~ s/\<!--\s+\$\$\$\$BODY\$\$\$\$\s+\-\-\>/$body/;
    $template =~ s/(<!--\s+\$\$\$\$TITLE\$\$\$\$\s+\-\-\>).*(?:\1)/$1$name$1/;
    
    open (my $dump, '>', $dump_filename) or die $!;
    print $dump $template;
    close $dump;
}

sub dump_single_layer {
    my ($layer, $name, $alloc) = @_;
    my $map = $layer->{'map'};
    
    my $maxrow = $#{ $map->{'Tiles'} };
    my $maxcol = $#{ $map->{'Tiles'}[0] };
    
    my @cells;
    foreach my $y (reverse(0..$maxcol)) {
    
        my @row;
        foreach my $x (0..$maxrow) {
            my $tile = $map->{'Tiles'}[$x][$y];
            
            if (!defined $alloc) {
                push @row, $tile->to_cell(0);
            }
            else {
                push @row, $tile->to_cell(1, $alloc->{$x}{$y});
            }
        }
        
        push @cells, \@row;
    }
    
    my $info = dump_layer_info($layer);
    return [$name, $info, \@cells];
}

sub dump_layer_info {
    my ($layer) = @_;
    
    my $speed = lc $layer->get_speed();
    my $size = lc $layer->get_size();
    my $era = lc $layer->get_era();
    
    $speed =~ s/^gamespeed_//i;
    $size =~ s/^worldsize_//i;
    $era =~ s/^era_//i;
    
    my $info = sprintf '<p><b>Speed:</b> %s, <b>Size:</b> %s, <b>Starting Era:</b> %s</p>', ucfirst($speed), ucfirst($size), ucfirst($era);
    
    my ($template) = slurp('debug/info.html.tmpl');
    $template =~ s/\<!--\s+\$\$\$\$INFO\$\$\$\$\s+\-\-\>/$info/;
    
    return [$template];
}
    
1;