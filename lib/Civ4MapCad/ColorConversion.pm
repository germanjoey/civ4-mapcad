package Civ4MapCad::ColorConversion;

use strict;
use warnings;

use List::Util qw(min max);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(mix_colors_by_color mix_colors_by_alpha);

# input is a list of: [color names, weight]
# we only look at the weights!
# this uses semi-transparent overlays to mix colors in the browser by placing
# overlays on top of each other, according to how well each civ settled each site
sub mix_colors_by_alpha {
    my (@in_colors) = @_;
    
    my $sum = 0;
    my @w;
    foreach my $color (@in_colors) {
        use Data::Dumper;
        print Dumper \@in_colors unless defined($color) and defined($color->[1]);
    
        $sum += $color->[1];
        push @w, $color->[1];
    }
    
    # now scale the weights to sum to 1
    # just in case we have a weird 2nd ring coast tile or something
    my @sw;
    foreach my $w (@w) {
        push @sw, $w/$sum;
    }
    
    # sort from smallest to biggest by INDEX
    my @ssi = sort { $sw[$a] <=> $sw[$b] } (0..$#sw);
    my @ssw = @sw[@ssi];
    
    # scale the total alpha; more mixed cells will be more opaque
    # so that they'll stand out more
    my $maxa = $ssw[-1];
    
    # scale (0.5 to 1] to [1 to 0.5]
    my $allowed_alpha = 1 - max(0, min(1,$maxa)-0.5);
    
    # now do the layering
    my @prefinal;
    my $fact = 1;
    foreach my $ssw (@ssw) {
        my $next = $ssw/$fact;
        push @prefinal, $next;
        $fact = $fact*(1-$next);
    }
    
    my @final;
    for my $i (0..$#prefinal) {
        my $adjusted = $prefinal[$i]*$sum*$allowed_alpha;
        $final[$i] = [$in_colors[$ssi[$i]][0], $in_colors[$ssi[$i]][1], $adjusted]
    }
    
    return @final;
}


# input is a list of: [colors in rgb hex, weight]
sub mix_colors_by_color {
    my @in_colors = @_;
    
    my $weight_total = 0;
    foreach my $rgb_color (@in_colors) {
        $weight_total += $rgb_color->[1];
    }
    
    my @cmyk_total = (0,0,0,0);
    foreach my $rgb_color (@in_colors) {
        my @cmyk_color = rgb_to_cymk($rgb_color);
        $cmyk_total[$_] += $cmyk_color[$_]/$weight_total for (0..3);
    }
    
    return cmyk_to_rgb(@cmyk_total);
}

# we dont use the cymk color mixing anymore, because it sucks ass,
# but might as well leave these here just in case, right?
sub rgb_to_cymk {
    my ($rgbw) = @_;
    my ($rgb, $w) = @$rgbw;
    
    $rgb =~ s/^#//;
    
    my $r = hex substr($rgb, 0, 2);
    my $g = hex substr($rgb, 2, 4);
    my $b = hex substr($rgb, 4, 6);
    
    my $c = 255 - $r;
    my $m = 255 - $g;
    my $y = 255 - $b;
    my $k = min($c, $m, $y);
    
    $c = ($c - $k)/(255 - $k);
    $m = ($m - $k)/(255 - $k);
    $y = ($y - $k)/(255 - $k);
    
    return [$c*$w, $m*$w, $y*$w, $k*$w];
}

sub cmyk_to_rgb {
  my ($c, $m, $y, $k) = @_;
  
  my $r = $c*(1-$k) + $k;
  my $g = $m*(1-$k) + $k;
  my $b = $y*(1-$k) + $k;
     $r = sprintf '%02x', int(255*(1-$r) + 0.5);
     $g = sprintf '%02x', int(255*(1-$g) + 0.5);
     $b = sprintf '%02x', int(255*(1-$b) + 0.5);
  
  return "#$r$g$b";
}

1;