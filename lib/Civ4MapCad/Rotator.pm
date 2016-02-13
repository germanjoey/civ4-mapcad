package Civ4MapCad::Rotator;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(rotate_grid flip_lr flip_tb);

use POSIX qw(ceil);
use List::Util qw(min);
use Algorithm::Line::Bresenham qw(line);

# This function tries as best as it can to rotate a grid of stuff.
# Accepts an input grid and a rotation_angle *BETWEEN 0 AND 45 DEGREES*
# the rotation accuracy gets worse the higher the angle is, which is due
# to the intrinsic error in trying to rotate a tile grid without empty
# spaces in between. (think about it: you're rotating a grid, but the tiles
# themselves still have the same orientation!) To adjust for this, you can
# specify the last parameter, $it, to be a value greater than 1. in this case,
# the algorithm will attempt to rotate a pattern in small steps; e.g. if
# $rotation_angle=39 and $it=3, we'll do 3 rotations of 13 degrees. Rotating in
# small steps like this gives a more accurate output angle but will jumble the
# result a bit more; again, some error is unavoidable due to the discrete nature
# of the problem.

# the output will be the grid, the new width and height, and the actual
# angle of rotation of the output as measured in two different ways. 
# the output grid will be bigger than the input; new blank spaces will
# have undefined values, so remember to fill those in yourself.

# input angle is in degrees
sub rotate_grid {
    my ($grid, $width, $height, $angle, $it, $autocrop) = @_;
    
    # normalize the angle
    while ($angle < 0) {
        $angle += 360;
    }
    $angle = $angle % 360;
    my $original_angle = $angle;
    
    my $move_x = 0;
    my $move_y = 0;
    my $expand_width = 0;
    my $expand_height = 0;
    my $result_angle1 = 0;
    my $result_angle2 = 0;
    
    # now deal with the "easy" cases. in addition to shifting the grid, we
    # have to figure out how much to expand the canvas by and how we'll need
    # to move the tiles afterwards
    if ($angle >= 270) {
        ($grid, $width, $height) = rotate270($grid, $width, $height);
        $angle -= 270;
        $result_angle1 += 270;
        $move_y = -$height - 1;
        $expand_height = $height;
    }
    elsif ($angle >= 180) {
        ($grid, $width, $height) = rotate180($grid, $width, $height);
        $angle -= 180;
        $result_angle1 += 180;
        $move_x = -$width - 1;
        $move_y = -$height - 1;
        $expand_width = $width;
        $expand_height = $height;
    }
    elsif ($angle >= 90) {
        ($grid, $width, $height) = rotate90($grid, $width, $height);
        $angle -= 90;
        $result_angle1 += 90;
        $move_x = -$width - 1;
        $expand_width = $width;
    }
    
    $result_angle2 = $result_angle1;
    
    # here is where things get messy
    if ($angle > 0) {
        my $adjust_45 = 0;
        if ($angle > 45) {
            # here we transpose without the corresponding adjustments
            # so that we can accurately rotate by the correct angle in the next step
            # (because rotate_small sucks for angles > 45 degrees)
            ($grid, $width, $height) = transpose_grid($grid, $width, $height);
            ($grid, $width, $height) = flip_lr($grid, $width, $height);
            ($grid, $width, $height) = flip_tb($grid, $width, $height);
            $angle -= 45;
            $result_angle1 += 45;
            $result_angle2 += 45;
            $adjust_45 = 1;
        }
    
        my $extrema;
        ($grid, $width, $height, $extrema) = rotate_grid_small($grid, $width, $height, $angle, $it);
        
        $result_angle1 += $extrema->{'angle'}[0];
        $result_angle2 += $extrema->{'angle'}[1];
        
        if ($adjust_45) {
            ($grid, $width, $height) = flip_tb($grid, $width, $height);
            
            if ($original_angle > 270) {
                $move_y -= ($height - $extrema->{'right'}[1] - 1);
            }
            elsif ($original_angle > 180) {
                $move_x -= ($width - $extrema->{'bottom'}[0] - 1);
            }
            elsif ($original_angle > 90) {
                $move_y += $extrema->{'left'}[1];
            }
            else {
                $move_x += $extrema->{'top'}[0];
            }
        }
        else {
            if ($original_angle > 270) {
                $move_y -= ($height - $extrema->{'left'}[1] - 1);
            }
            elsif ($original_angle > 180) {
                $move_x -= ($width - $extrema->{'top'}[0] - 1);
            }
            elsif ($original_angle > 90) {
                $move_y += $extrema->{'right'}[1];
            }
            else {
                $move_x += $extrema->{'bottom'}[0];
            }
        }
    }
    
    if ($autocrop == 0) {
        $width += $expand_width;
        $height += $expand_height;
    }
    
    # TODO: need to correctly validate move; move_left is not enough; e.g. a move of 180 degrees needs to move down too
    
    return ($grid, $width, $height, $move_x, $move_y, $result_angle1, $result_angle2);
}

sub rotate90 {
    my ($grid, $width, $height) = @_;
    ($grid, $width, $height) = transpose_grid($grid, $width, $height);
    ($grid, $width, $height) = flip_lr($grid, $width, $height);
    return ($grid, $width, $height);
}

sub rotate180 {
    my ($grid, $width, $height) = @_;
    ($grid, $width, $height) = flip_lr($grid, $width, $height);
    ($grid, $width, $height) = flip_tb($grid, $width, $height);
    
    return ($grid, $width, $height);
}

sub rotate270 {
    my ($grid, $width, $height) = @_;
    ($grid, $width, $height) = transpose_grid($grid, $width, $height);
    ($grid, $width, $height) = flip_tb($grid, $width, $height);
    return ($grid, $width, $height);
}

sub rotate_grid_small {
    my ($input, $width, $height, $rotation_angle, $it) = @_; 

    my $grid = $input;
    my $angle_step = $rotation_angle/$it;
    my $extrema;
    
    while ($rotation_angle > 0) {
        my $angle = min($angle_step, $rotation_angle);
        $rotation_angle -= $angle_step;
        my $angle_rads = $angle*3.14159265/180;
        
        # with (center.x, center.y) = (0,0)
        # rotatedX = Math.cos(angle) * (point.x - center.x) - Math.sin(angle) * (point.y - center.y) + center.x;
        # rotatedY = Math.sin(angle) * (point.x - center.x) + Math.cos(angle) * (point.y - center.y) + center.y;
        
        my $top_right_x = ceil(($width-1)*cos($angle_rads) - ($height-1)*sin($angle_rads));
        my $top_right_y = ceil(($width-1)*sin($angle_rads) + ($height-1)*cos($angle_rads));

        my $bot_right_x = ceil(($width-1)*cos($angle_rads) - 0*sin($angle_rads));
        my $bot_right_y = ceil(($width-1)*sin($angle_rads) + 0*cos($angle_rads));

        my $top_left_x = ceil(0*cos($angle_rads) - ($height-1)*sin($angle_rads));
        my $top_left_y = ceil(0*sin($angle_rads) + ($height-1)*cos($angle_rads));

        my ($h_pattern_width, $h_pattern_height, $rot_pattern_horizontal) = get_rot_pattern_horizontal($width, $bot_right_x, $bot_right_y);
        my ($v_pattern_width, $v_pattern_height, $rot_pattern_vertical) = get_rot_pattern_vertical($height, $top_left_x, $top_left_y);
        
        ($grid, $width, $height, $extrema) = rotate_matrix ($grid, $width, $height, $rot_pattern_horizontal, $rot_pattern_vertical);
    }
    
    return ($grid, $width, $height, $extrema);
}

sub get_rot_pattern_horizontal {
    my ($gwidth, $to_x, $to_y) = @_;
    my @rot_pattern = line(0,0 => $to_y,$to_x);

    if (@rot_pattern < $gwidth) {
        my @rot_pattern_back = line(0,0 => (-$to_y),(-$to_x));
        shift @rot_pattern_back;
        while (@rot_pattern < $gwidth) {
            my $next_point = shift @rot_pattern_back;
            my ($y,$x) = @$next_point;
            unshift @rot_pattern, $next_point;
        }
    }
    elsif (@rot_pattern > $gwidth) {
        while (@rot_pattern > $gwidth) {
            pop @rot_pattern;
        }
    }
    
    normalize_pattern(\@rot_pattern);
    
    my $pwidth = abs($rot_pattern[-1][1] - $rot_pattern[0][1]) + 1;
    my $pheight = abs($rot_pattern[-1][0] - $rot_pattern[0][0]) + 1;
    
    return ($pwidth, $pheight, \@rot_pattern);
}

sub get_rot_pattern_vertical {
    my ($gheight, $to_x, $to_y) = @_;
    my @rot_pattern = line(0,0 => $to_y,$to_x);

    if (@rot_pattern < $gheight) {
        my @rot_pattern_back = line(0,0 => (-$to_y),(-$to_x));
        shift @rot_pattern_back;
        while (@rot_pattern < $gheight) {
            my $next_point = shift @rot_pattern_back;
            unshift @rot_pattern, $next_point;
        }
        
    }
    elsif (@rot_pattern > $gheight) {
        while (@rot_pattern > $gheight) {
            pop @rot_pattern;
        }
        
        my $min_x = 0;
        my $min_y = 0;
    }
    
    normalize_pattern(\@rot_pattern);
    
    my $pwidth = abs($rot_pattern[-1][1] - $rot_pattern[0][1]) + 1;
    my $pheight = abs($rot_pattern[-1][0] - $rot_pattern[0][0]) + 1;
    
    return ($pwidth, $pheight, \@rot_pattern);
}

sub normalize_pattern {
    my ($pattern) = @_;
    
    my $min_x = $pattern->[0][1];
    my $min_y = $pattern->[0][0];
    
    foreach my $p (@$pattern) {
        my ($y,$x) = @$p;
        $min_x = $x if $x < $min_x;
        $min_y = $y if $y < $min_y;
    }
    
    foreach my $p (@$pattern) {
        $p->[0] -= $min_y;
        $p->[1] -= $min_x;
    }
}

sub show_pattern {
    my ($width, $height, $pattern) = @_;
    
    print (("-" x (2*@$pattern)) . "\n");
    
    for my $i (0..$#$pattern) {
        my $p = $pattern->[$i];
        my ($y, $x) = @$p;
        print "$i / $x / $y\n";
    }
    
    print (("-" x (2*@$pattern)) . "\n");

    print "\n$width / $height / " . (@$pattern+0) . "\n\n";

    print (("-" x (2*@$pattern)) . "\n");
    my @full_pattern;
    foreach my $x (0..$width-1) {
        $full_pattern[$x] = [];
        foreach my $y (0..$height-1) {
            $full_pattern[$x][$y] = ' ';
        }
    }

    foreach my $p (@$pattern) {
        my ($y,$x) = @$p;
        $full_pattern[$x][$y] = 'x';
    }

    my $count = 0;
    foreach my $y (0..$height-1) {
        foreach my $x (0..$width-1) {
            $count ++ if $full_pattern[$x][$height-1-$y] eq 'x';
            print $full_pattern[$x][$height-1-$y];
        }
        print "\n";
    }
    
    print "\n$count 'x's seen\n";

}

sub rotate_matrix {
    my ($grid, $width, $height, $rot_pattern_horizontal, $rot_pattern_vertical) = @_;
    
    my @rotated;
    foreach my $x (0..$width-1) {
        $rotated[$x] = [];
    }
    
    # rotate the grid by slotting into the two intersecting bresenham templates
    my $max_x = 0; my $max_y = 0;
    foreach my $y (0..$height-1) {
        my $adjust_h = $rot_pattern_vertical->[$y];
        foreach my $x (0..$width-1) {
            my $adjust_v = $rot_pattern_horizontal->[$x];
            
            my $dx = $x - $adjust_v->[1];
            my $dy = $y - $adjust_h->[0];
            
            my $ax = $adjust_h->[1] + $dx;
            my $ay = $adjust_v->[0] + $dy;
            
            my $adjusted_x = $x + $ax;
            my $adjusted_y = $y + $ay;
            
            $rotated[$adjusted_x][$adjusted_y] = $grid->[$x][$y];
            $max_x = $adjusted_x if $adjusted_x > $max_x;
            $max_y = $adjusted_y if $adjusted_y > $max_y;
        }
    }
    
    my ($compressed, $total_skipped) = compress_rotation(\@rotated, $max_x, $max_y);
    
    my $new_width = $max_x + $total_skipped + 1;
    my $new_height = $max_y + 1;
    my $extrema = find_result_angles($compressed, $new_width, $new_height);
    
    ($compressed, $new_width, $new_height) = crop_empty_columns($compressed, $new_width, $new_height, $extrema);
    
    return ($compressed, $new_width, $new_height, $extrema);
}

# now compress all the empty spaces... this won't necessarily preserve the angle!
# and might slightly skew the result! but its the best we can do!
sub compress_rotation {
    my ($grid, $max_x, $max_y) = @_;

    my @compressed;
    my $total_skip = 0;
    foreach my $yy (0..$max_y) {
        my $seen = 0;
        my $skip = 0;
        my $to_skip = 0;
        my $first_x = $max_x;
        my $y = $max_y - $yy;
        
        foreach my $x (0..$max_x) {
            if (($seen == 0) and defined($grid->[$x][$y])) {
                $seen = 1;
                $first_x = $x;
            }
            elsif (($seen == 0) and (! defined $grid->[$x][$y])) {
                next;
            }
            elsif (($seen == 1) and (! defined $grid->[$x][$y])) {
                $to_skip ++;
                next;
            }
            elsif (($seen == 1) and (defined $grid->[$x][$y])) {
                $skip += $to_skip;
                $to_skip = 0;
                next;
            }
        }
        
        $total_skip = $skip if $skip > $total_skip;
        
        my $c = 0;
        foreach my $x ($first_x..$max_x) {
            if (!defined $grid->[$x][$y]) {
                $c++;
                next;
            }
            
            $compressed[$x+$total_skip-$c][$y] = $grid->[$x][$y];
        }
    }
    
    return (\@compressed, $total_skip)
}

sub crop_empty_columns {
    my ($grid, $width, $height, $extrema) = @_;
    
    my @new;
    foreach my $y (0..$height-1) {
        foreach my $x ($extrema->{'left'}[0]..$width-1) {
            $new[$x-$extrema->{'left'}[0]][$y] = $grid->[$x][$y];
        }
    }
    
    my $to_cut = 0;
    $to_cut += $extrema->{'left'}[0] if $extrema->{'left'}[0] > 0;
    $to_cut += (($width-1) - $extrema->{'right'}[0]) if $extrema->{'right'}[0] < ($width-1);
    
    foreach my $x ((($width-1)-($to_cut-1))..$width-1) {
        delete $new[$x];
    }
    
    $extrema->{'bottom'}[0] -= $extrema->{'left'}[0];
    $extrema->{'top'}[0] -= $extrema->{'left'}[0];
    $extrema->{'left'}[0] = 0;
    $width = $width - $to_cut;
    $extrema->{'right'}[0] = $width - 1;
    
    return (\@new, $width, $height);
}   

sub find_result_angles {
    my ($grid, $width, $height) = @_; 

    my $found = 0;
    my %extrema = (
        'left' => [-1,0],
        'bottom' => [0,-1],
        'right' => [$width,0],
        'top' => [0,$height],
    );
    
    while ($found == 0) {
        $extrema{'left'}[0] ++;
        foreach my $y (0..$height-1) {
            if (defined($grid->[$extrema{'left'}[0]]) and defined($grid->[$extrema{'left'}[0]][$height - 1 - $y])) {
                $extrema{'left'}[1] = $height - 1 - $y;
                $found = 1;
                last;
            }
        }
    }
    
    $found = 0;
    while ($found == 0) {
        $extrema{'right'}[0] --;
        foreach my $y (0..$height-1) {
            if (defined($grid->[$extrema{'right'}[0]]) and defined($grid->[$extrema{'right'}[0]][$y])) {
                $extrema{'right'}[1] = $y;
                $found = 1;
                last;
            }
        }
    }
    
    $found = 0;
    while ($found == 0) {
        $extrema{'top'}[1] --;
        foreach my $xx (0..$width-1) {
            my $x = $width - 1 - $xx;
            if (defined $grid->[$x][$extrema{'top'}[1]]) {
                $extrema{'top'}[0] = $x;
                $found = 1;
                last;
            }
        }
    }
    
    $found = 0;
    while ($found == 0) {
        $extrema{'bottom'}[1] ++;
        foreach my $x (0..$width-1) {
            if (defined $grid->[$x][$extrema{'bottom'}[1]]) {
                $extrema{'bottom'}[0] = $x;
                $found = 1;
                last;
            }
        }
    }
    
    my $aa1 = abs($extrema{'left'}[0] - $extrema{'bottom'}[0]) + 1;
    my $aa2 = abs($extrema{'left'}[1] - $extrema{'bottom'}[1]) + 1;
    my $angle1 = atan2($aa1,$aa2)*180/3.14159265;
    
    my $ab1 = abs($extrema{'top'}[0] - $extrema{'left'}[0]) + 1;
    my $ab2 = abs($extrema{'top'}[1] - $extrema{'left'}[1]) + 1;
    my $angle2 = atan2($ab2,$ab1)*180/3.14159265;
    
    $extrema{'angle'} = [$angle1, $angle2];
    
    return \%extrema;
}

sub flip_lr {
    my ($grid, $width, $height) = @_;
    
    my @new;
    foreach my $xx (0..$width-1) {
        my $x = $width - 1 - $xx;
        $new[$x] = [];
        
        foreach my $y (0..$height-1) {
            $new[$x][$y] = $grid->[$xx][$y];
            
            if (ref($new[$x][$y]) =~ /tile/i) {
                $new[$x][$y]->set('x', $x);
                $new[$x][$y]->flip_rivers_lr();
            }
        }
    }
    
    foreach my $x (0..$width-1) {
        foreach my $y (0..$height-1) {
            next unless defined($new[$x][$y]);
            next unless ref($new[$x][$y]) =~ /tile/i;
            
            if (defined($new[$x-1][$y])) {
                next unless exists $new[$x][$y]{'isWOfRiver'};
                
                $new[$x-1][$y]{'isWOfRiver'} = $new[$x][$y]{'isWOfRiver'};
                $new[$x-1][$y]{'RiverNSDirection'} = $new[$x][$y]{'RiverNSDirection'};
            }
            
            delete $new[$x][$y]{'RiverNSDirection'};
            delete $new[$x][$y]{'isWOfRiver'};
        }
    }
    
    return (\@new, $width, $height);
}

sub flip_tb {
    my ($grid, $width, $height) = @_;
    
    my @new;
    foreach my $x (0..$width-1) {
        $new[$x] = [];
        
        foreach my $yy (0..$height-1) {
            my $y = $height - 1 - $yy;
            $new[$x][$y] = $grid->[$x][$yy];
            
            if (ref($new[$x][$y]) =~ /tile/i) {
                $new[$x][$y]->set('y', $y);
                $new[$x][$y]->flip_rivers_tb();
            }
        }
    }
    
    foreach my $yy (0..$height-1) {
        my $y = $height - 1 - $yy;
        my $yp1 = $y + 1;
        $yp1 = 0 if $yp1 == $height;
        
        foreach my $x (0..$width-1) {
            next unless defined($new[$x][$y]);
            next unless ref($new[$x][$y]) =~ /tile/i;
            
            if (defined($new[$x][$yp1])) {
                next unless exists $new[$x][$y]{'isNOfRiver'};
                
                $new[$x][$yp1]{'isNOfRiver'} = $new[$x][$y]{'isNOfRiver'};
                $new[$x][$yp1]{'RiverWEDirection'} = $new[$x][$y]{'RiverWEDirection'};
            }
            
            delete $new[$x][$y]{'RiverWEDirection'};
            delete $new[$x][$y]{'isNOfRiver'};
        }
    }
    
    return (\@new, $width, $height);
}

sub transpose_grid {
    my ($grid, $width, $height) = @_;
    
    my @new;
    for my $y (0..$height-1) {
        $new[$y] = [];
    }
    
    for my $x (0..$width-1) {
        for my $y (0..$height-1) {
            $new[$y][$x] = $grid->[$x][$y];
            
            if (ref($new[$y][$x]) =~ /tile/i) {
                $new[$y][$x]->transpose_rivers();
            }
        }
    }
    
    # now fix the river offset
    
    foreach my $yy (0..$width-1) {
        my $y = $width - 1 - $yy;
        foreach my $x (0..$height-1) {
            next unless defined($new[$x][$y]);
            next unless ref($new[$x][$y]) =~ /tile/i;
            
            my $yp1 = $y + 1;
            #$yp1 = 0 if $yp1 == $width;
            
            if (defined($new[$x][$yp1])) {
                next unless exists $new[$x][$y]{'isNOfRiver'};
                
                $new[$x][$yp1]{'isNOfRiver'} = $new[$x][$y]{'isNOfRiver'};
                $new[$x][$yp1]{'RiverWEDirection'} = $new[$x][$y]{'RiverWEDirection'};
            }
            
            delete $new[$x][$y]{'isNOfRiver'};
            delete $new[$x][$y]{'RiverWEDirection'};
        }
    }
    
    foreach my $x (0..$height-1) {
        foreach my $y (0..$width-1) {
            next unless defined($new[$x][$y]);
            next unless ref($new[$x][$y]) =~ /tile/i;
            
            if (defined($new[$x-1][$y])) {
                next unless exists $new[$x][$y]{'isWOfRiver'};
                
                $new[$x-1][$y]{'isWOfRiver'} = $new[$x][$y]{'isWOfRiver'};
                $new[$x-1][$y]{'RiverNSDirection'} = $new[$x][$y]{'RiverNSDirection'};
            }
            
            delete $new[$x][$y]{'RiverNSDirection'};
            delete $new[$x][$y]{'isWOfRiver'};
        }
    }
    
    return (\@new, $height, $width);
}

1;