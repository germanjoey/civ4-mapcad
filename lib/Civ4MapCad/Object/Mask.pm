package Civ4MapCad::Object::Mask;
 
use strict;
use warnings;

use List::Util qw(min max);
use Civ4MapCad::Ascii qw(import_ascii_mask export_ascii_mask);
use Civ4MapCad::Rotator qw(rotate_grid);

our $epsilon = 0.00001;

sub new_blank {
    my ($class, $width, $height) = @_;
    
    my %obj = (
        'width' => $width, # width of the canvas
        'height' => $height, # height of the canvas
        'canvas' => [],
    );
    
    foreach my $x (0..($width-1)) {
        $obj{'canvas'}[$x] = [];
        foreach my $y (0..($height-1)) {
            $obj{'canvas'}[$x][$y] = 0;
        }
    }
   
    return bless \%obj, $class;
}

sub new_from_shape {
    my ($class, $width, $height, $shape, $shape_params) = @_;
 
    my %obj = (
        'width' => $width, # width of the canvas
        'height' => $height, # height of the canvas
        'canvas' => [],
    );
    
    foreach my $x (0..($width-1)) {
        $obj{'canvas'}[$x] = [];
        foreach my $y (0..($height-1)) {
            my $val = $shape->($shape_params, $x, $y, 1);
            $obj{'canvas'}[$x][$y] = max(0, min(1, $val));
        }
    }
   
    return bless \%obj, $class;
}

sub new_from_ascii {
    my ($class, $filename, $mapping) = @_;
   
    my $result = import_ascii_mask($filename, $mapping);
    if (exists $result->{'error'}) {
        return $result;
    }
    
    # TODO: are these two right?
    my $height = @{ $result->{'canvas'} } + 0;
    my $width = @{ $result->{'canvas'}[0] } + 0;
    
    my %obj = (
        'width' => $width, # width of the canvas
        'height' => $height, # height of the canvas
        'canvas' => $result->{'canvas'}
    );
   
    return bless \%obj, $class;
}

sub export_to_ascii {
    my ($self, $filename, $mapping) = @_;
    
    my %reversed;
    while ( my($k,$v) = each %$mapping ) {
        $reversed{$v} = $k;
    }
    
    export_ascii_mask($filename, $self->{'canvas'}, $self->{'width'}, $self->{'height'}, \%reversed);
}

# TODO!
sub new_from_layer {
    die "TODO: new from layer";
}

# e.g. this is a file w/ each line being x y value
sub new_from_file {
    my ($class, $filename) = @_;
    
    open (my $file, $filename);
    my @lines = <$file>;
    close $file;
    
    my @canvas;
    my ($maxX, $maxY) = (-1, -1);
    foreach my $line (@lines) {
        next unless $line =~ /\w/;
        my ($x, $y, $value) = split ' ', $line;
        unless (defined($x) and defined($y) and defined($value)) {
            return {
                'error' => 1,
                'error_msg' => "Parse error attempting to import mask from file '$filename'"
            };
        }
        
        $maxX = $x if $x > $maxX;
        $maxY = $y if $y > $maxY;
        
        $canvas[$x][$y] = $value;
    }
    
    my %obj = (
        'width' => ($maxX+1), # width of the canvas
        'height' => ($maxY+1), # height of the canvas
        'canvas' => \@canvas
    );
   
    return bless \%obj, $class;
}

sub export_to_file {
    my ($self, $filename) = @_;
    
    open (my $file, '>', $filename) or die $!;
    
    foreach my $x (0..($self->{'width'}-1)) {
        foreach my $y (0..($self->{'height'}-1)) {
            my $out = sprintf "%3d %3d %6.4f\n", $x, $y, $self->{'canvas'}[$x][$y];
            print $file $out;
        }
    }
    
    close $file;
}

sub get_width {
    my ($self) = @_;
    return $self->{'width'};
}

sub get_height {
    my ($self) = @_;
    return $self->{'height'};
}

sub _max_size {
    my ($self, $other, $offsetX, $offsetY) = @_;
    
    my $left = min(0, $offsetX);
    my $right = max($self->get_width(), $other->get_width() + $offsetX);
    my $bottom = min(0, $offsetY);
    my $top = max($self->get_height(), $other->get_height() + $offsetY);
    
    return ($right - $left, $top - $bottom);
}

sub _set_opt {
    my ($self, $othr, $offsetX, $offsetY, $subopt) = @_;
    
    my ($width, $height) = _max_size($self, $othr, $offsetX, $offsetY);
    my $new = Civ4MapCad::Object::Mask->new_blank($width, $height);
    
    foreach my $x (0..$width-1) {
        foreach my $y (0..$height-1) {
            my $aX = ($offsetX >= 0) ? $x : ($x + $offsetX);
            my $aY = ($offsetY >= 0) ? $y : ($y + $offsetY);
            my $bX = ($offsetX >= 0) ? ($x - $offsetX) : $x;
            my $bY = ($offsetY >= 0) ? ($y - $offsetY) : $y;
            
            my $a_val = (($aX >=0) and ($aX < $self->{'width'}) and ($aY >=0) and ($aY < $self->{'height'})) ? $self->{'canvas'}[$aX][$aY] : 0;
            my $b_val = (($bX >=0) and ($bX < $othr->{'width'}) and ($bY >=0) and ($bY < $othr->{'height'})) ? $othr->{'canvas'}[$bX][$bY] : 0;
            
            $new->{'canvas'}[$x][$y] = max(0, min(1, $subopt->($a_val, $b_val, $x, $y)));
        }        
    }
    
    return $new;
}

sub _self_opt {
    my ($self, $subopt) = @_;
    
    my $new = Civ4MapCad::Object::Mask->new_blank($self->{'width'}, $self->{'height'});
    
    foreach my $x (0..$self->{'width'}-1) {
        foreach my $y (0..$self->{'height'}-1) {
            $new->{'canvas'}[$x][$y] = max(0, min(1, $subopt->($self->{'canvas'}[$x][$y])));
        }
    }
    
    return $new;
}

sub apply_shape {
    my ($self, $shape, $shape_params) = @_;
    
    my $width = $self->get_width();
    my $height = $self->get_height();
    
    my $new = Civ4MapCad::Object::Mask->new_blank($width, $height);
 
    foreach my $x (0..($width-1)) {
        foreach my $y (0..($height-1)) {
            my $val = $shape->($shape_params, $x, $y, $self->{'canvas'}[$x][$y]);
            $new->{'canvas'}[$x][$y] = max(0, min(1, $val));
        }
    }
    
    return $new;
}

sub intersection {
    my ($self, $other, $offsetX, $offsetY) = @_;
    return $self->_set_opt($other, $offsetX, $offsetY, sub { my ($x,$y) = @_; return $x*$y })
}

sub union {
    my ($self, $other, $offsetX, $offsetY) = @_;
    return $self->_set_opt($other, $offsetX, $offsetY, sub { my ($x,$y) = @_; return min(1, $x+$y) }) 
}

sub difference {
    my ($self, $other, $offsetX, $offsetY) = @_;
    return $self->_set_opt($other, $offsetX, $offsetY, sub { my ($x,$y) = @_; return max(0, $x-$y) }) 
}

sub invert {
    my ($self) = @_;
    return $self->_self_opt(sub { return 1 - $_[0] }) 
}

sub threshold {
    my ($self, $level) = @_;
    return $self->_self_opt(sub { return (($_[0] > $level) ? 1 : 0) })
}

sub count_matches {
    my ($self, $value) = @_;
    
    my $count = 0;
    foreach my $x (0..($self->get_width()-1)) {
        foreach my $y (0..($self->get_height()-1)) {
            $count += $self->compare_value($x, $y, $value);
        }
    }
        
    return $count;
}

sub grow_bfc {
    my ($self, $threshold, $wrapX, $wrapY) = @_;
    my $old_mask = $self->threshold($threshold); # copies the original
    
    my $width = $self->get_width();
    my $height = $self->get_height();
    
    my $growing_mask = Civ4MapCad::Object::Mask->new_blank($width, $height);
    
    my $min_x = $width; my $max_x = 0;
    my $min_y = $height; my $max_y = 0;
    foreach my $x (0 .. ($growing_mask->get_width() - 1)) {
        foreach my $y (0 .. ($growing_mask->get_height() - 1)) {
            next unless $old_mask->compare_value($x, $y, 1);

            foreach my $ddx (0..4) {
                my $dx = $ddx - 2;
                foreach my $ddy (0..4) {
                    my $dy = $ddy - 2;
                    
                    next if ($dx == 0) and ($dy == 0); # skip city tile
                    next if (abs($dx) == 2) and (abs($dy) == 2); # skip corners
                    
                    my $use_x = $x + $dx;
                    my $use_y = $y + $dy;
                    
                    if ($wrapX == 1) {
                        if ($use_x > $width) {
                            $use_x -= $width;
                        }
                        elsif ($use_x < 0) {
                            $use_x += $width;
                        }
                    }
                    elsif (($use_x > $height) or ($use_x < 0)) {
                        next;
                    }
                    
                    if ($wrapY == 1) {
                        if ($use_y > $height) {
                            $use_y -= $height;
                        }
                        elsif ($use_y < 0) {
                            $use_y += $height;
                        }
                    }
                    elsif (($use_y > $height) or ($use_y < 0)) {
                        next;
                    }
                    
                    $growing_mask->{'canvas'}[$use_x][$use_y] = 1;
                }
            }
        }        
    }
}

sub grow {
    my ($self, $amount, $threshold, $rescale) = @_;
    
    my $old_mask = $self->threshold($threshold); # copies the original
    my $overfold_warning = 0;
    foreach my $i (1..$amount) {
        my $growing_mask = Civ4MapCad::Object::Mask->new_blank($old_mask->get_width()+2, $old_mask->get_height()+2);
        
        my $min_x = $old_mask->get_width(); my $max_x = 0;
        my $min_y = $old_mask->get_height(); my $max_y = 0;
        foreach my $x (0 .. ($growing_mask->get_width() - 1)) {
            foreach my $y (0 .. ($growing_mask->get_height() - 1)) {
                $growing_mask->{'canvas'}[$x][$y] = $old_mask->check_mask_edges_for_value($x-1, $y-1, 1);
                
                $max_x = $x if $x > $max_x;
                $min_x = $x if $x < $min_x;
                $max_y = $y if $y > $max_y;
                $min_y = $y if $y < $min_y;
            }
        }
        
        if ($rescale and ($overfold_warning == 0)) {
            my $xwidth = $max_x - $min_x;
            my $ywidth = $max_y - $min_y;
            
            # first make sure we can chop off some empty space.
            if ( ($xwidth >= $old_mask->get_width()) or ($ywidth >= $old_mask->get_height()) ) {
                $old_mask = $growing_mask;
                $overfold_warning = 1;
                next;
            }
            
            ## e.g.
            # 40/40 -> move back 2
            # 39/40 -> move back 1
            # 38/40 -> move back none
            my $max_x_diff = $growing_mask->get_width() - 1 - $max_x;
            my $max_y_diff = $growing_mask->get_height() - 1 - $max_y;
            my $cut_x = max(0, 2 - $max_x_diff);
            my $cut_y = max(0, 2 - $max_y_diff);
            
            my $downsized_mask = Civ4MapCad::Object::Mask->new_blank($self->get_width(), $self->get_height());
            foreach my $x ($min_x .. $max_x) {
                foreach my $y ($min_y .. $max_y) {
                    $downsized_mask->{'canvas'}[$x-$cut_x][$y-$cut_y] = $growing_mask->{'canvas'}[$x][$y];
                }
            }
            
            $old_mask = $downsized_mask;
        }
        else {
            $old_mask = $growing_mask;
        }
    }
    
    if ($overfold_warning) {
        my $downsized_mask = Civ4MapCad::Object::Mask->new_blank($self->get_width(), $self->get_height());
        
        foreach my $x ($amount .. ($old_mask->get_width()-$amount-1)) {
            foreach my $y ($amount .. ($old_mask->get_height()-$amount-1)) {
                die "$x $y $amount " . $old_mask->get_width() . " " . $old_mask->get_height() unless defined $old_mask->{'canvas'}[$x][$y];
                $downsized_mask->{'canvas'}[$x-$amount][$y-$amount] = $old_mask->{'canvas'}[$x][$y];
            }
        }
        
        $downsized_mask->{'overfold_warning'} = 1;
        return $downsized_mask;
    }
    else {
        return $old_mask;
    }
}

sub shrink {
    my ($self, $amount, $threshold) = @_;
    
    my $old_mask = $self->threshold($threshold); # copies the original
    
    foreach my $i (1..$amount) {
        my $shrinking_mask = Civ4MapCad::Object::Mask->new_blank($old_mask->get_width(), $old_mask->get_height());
        
        foreach my $x (0 .. ($shrinking_mask->get_width()-1)) {
            $shrinking_mask->{'canvas'}[$x] = [];
            foreach my $y (0 .. ($shrinking_mask->get_height()-1)) {
                $shrinking_mask->{'canvas'}[$x][$y] = $old_mask->check_mask_edges_for_value($x, $y, 0);
            }
        }
        
        $old_mask = $shrinking_mask;
    }
    
    return $old_mask;
}

sub translate_xy {
    my ($self, $x, $y) = @_;
    
    my $tx = $x;
    my $ty = $y;

    if ($tx < 0) {
        return;
    }
    elsif ($tx >= $self->get_width()) {
        return;
    }
    
    if ($ty < 0) {
        return;
    }
    elsif ($ty >= $self->get_height()) {
        return;
    }
    
    return ($tx, $ty);
}

sub compare_value {
    my ($self, $x, $y, $value) = @_;
    return ((abs($value - $self->{'canvas'}[$x][$y]) <= $epsilon) ? 1 : 0);
}

sub check_mask_edges_for_value {
    my ($self, $x, $y, $value) = @_;
    
    my ($tx, $ty) = $self->translate_xy($x, $y);
    return $value if defined($tx) and defined($ty) and (abs($value - $self->{'canvas'}[$tx][$ty]) <= $epsilon);

    my @directions = ('1 1', '0 1', '-1 1', '1 0', '-1 0', '1 -1', '0 -1', '-1 -1');
    foreach my $direction (@directions) {
        my ($xd, $yd) = split ' ', $direction;
        my ($tx, $ty) = $self->translate_xy($x+$xd, $y+$yd);
        next unless (defined($tx) and defined($ty));
        
        return $value if $self->compare_value($tx, $ty, $value);
    }
    
    return (($value) ? 0 : 1);
}

sub rotate {
    my ($self, $angle, $it, $autocrop) = @_;
    
    return (0,0) if ($angle % 360) == 0;
    
    my $width = $self->get_width();
    my $height = $self->get_height();
    my ($grid, $new_width, $new_height, $move_x, $move_y, $result_angle1, $result_angle2) = rotate_grid($self->{'canvas'}, $width, $height, $angle, $it, $autocrop);
    
    $self->{'width'} = $new_width;
    $self->{'height'} = $new_height;
    
    foreach my $x (0..$new_width-1) {
        $self->{'canvas'}[$x] = [];
        foreach my $y (0..$new_height-1) {
            $self->{'canvas'}[$x][$y] = $grid->[$x][$y];
            $self->{'canvas'}[$x][$y] = 0.0 unless defined $grid->[$x][$y];
        }
    }
    
    return ($move_x, $move_y, $result_angle1, $result_angle2);
}

1;