package Civ4MapCad::Dump;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(dump_out dump_framework dump_single_layer);

sub dump_framework {
    my ($template_filename, $dump_filename, $name, $tabs) = @_;
    
    my @tab_heads; my @tab_bodies;
    foreach my $t (0..$#$tabs) {
        my ($name, $info, $rows) = @{ $tabs->[$t] };
        
        my $head = qq[<li><a href="#tabs-$t">$name</a></li>];
        
        my $body = qq[<div id="tabs-$t">\n];
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
    
    my $out;
    foreach my $th (@tab_heads) {
        $out .= "  $th\n";
    }
    $out .= "</ul>\n";
    foreach my $tb (@tab_bodies) {
        $out .= $tb;
    }
    
    dump_out($template_filename, $dump_filename, $name, $out);
}

sub dump_out {
    my ($template_filename, $dump_filename, $name, $output) = @_;
    
    my ($template) = slurp($template_filename);
    $output =~ s/\n/\n    /g;
    $template =~ s/\$\$\$\$DUMP\$\$\$\$/$output/;
    $template =~ s/\$\$\$\$HEADER\$\$\$\$/$name/;
    
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

sub slurp {
    my $file = shift;
    open my $fh, '<', $file or die;
    local $/ = undef;
    my $cont = <$fh>;
    close $fh;
    return $cont;
}
    
1;