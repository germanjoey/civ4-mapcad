package Civ4MapCad::Dump;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(dump_out dump_framework dump_single_layer);

use Civ4MapCad::Util qw(slurp);

sub dump_framework {
    my ($template_filename, $dump_filename, $name, $start_index, $tabs) = @_;
    
    my @tab_heads; my @tab_bodies;
    
    
    foreach my $t (0..$#$tabs) {
        my ($name, $info, $rows) = @{ $tabs->[$t] };
        
        my $id = $t + $start_index;
        my $head = qq[<li><a href="#tabs-$id">$name</a></li>];
        
        my $body = qq[<div id="tabs-$id">\n];
        #if (@$info > 0) {
        #    
        #}
        
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
    
    dump_out($template_filename, $dump_filename, $name, $head, $body);
}

sub dump_out {
    my ($template_filename, $dump_filename, $name, $head, $body) = @_;
    
    $head =~ s/\n/\n    /g;
    $body =~ s/\n/\n    /g;
    $head .= "\n		<!-- \$\$\$\$HEAD\$\$\$\$ -->\n";
    $body .= "\n		<!-- \$\$\$\$BODY\$\$\$\$ -->\n";
    
    my ($template) = slurp($template_filename);
    $template =~ s/\<!--\s+\$\$\$\$HEAD\$\$\$\$\s+\-\-\>/$head/;
    $template =~ s/\<!--\s+\$\$\$\$BODY\$\$\$\$\s+\-\-\>/$body/;
    $template =~ s/(<!--\s+\$\$\$\$TITLE\$\$\$\$\s+\-\-\>).*(?:\1)/$1$name$1/;
    
    open (my $dump, '>', $dump_filename) or die $!;
    print $dump $template;
    close $dump;
}

sub dump_single_layer {
    my ($layer, $do_info) = @_;
    
    my $map = $layer->{'map'};
    
    my $maxrow = $#{ $map->{'Tiles'} };
    my $maxcol = $#{ $map->{'Tiles'}[0] };
    
    my @cells;
    foreach my $y (reverse(0..$maxcol)) {
    
        my @row;
        foreach my $x (0..$maxrow) {
            my $tile = $map->{'Tiles'}[$x][$y];
            
            push @row, $tile->to_cell;
        }
        
        push @cells, \@row;
    }
    
    my $info = [];
    if ($do_info) {
        $info = dump_layer_info($layer);
    }
    
    return [$layer->get_name(), $info, \@cells];
}

sub dump_layer_info {
    my ($layer) = @_;
    return [];
}
    
1;