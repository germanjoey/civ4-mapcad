package Civ4MapCad::Object::Mask;
 
use strict;
use warnings;

use List::Util qw(min max);

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
            my $val = $shape->($shape_params, $x, $y);
            $obj{'canvas'}[$x][$y] = max(0, min(1, $val));
        }
    }
   
    return bless \%obj, $class;
}

# TODO: test this
sub new_from_ascii {
    my ($class, $filename, $weights) = @_;
   
    open (my $ascii, $filename) || 0;
   
    # construct the shape
    my @canvas;
    my $max_col = 0;
    while (1) {
        my ($line) = <$ascii>;
        last unless defined $line;
        chomp $line;
       
        my @chars = split '', $line;
        my @filtered;
        foreach my $i (0..$#chars) {
            foreach my $m (keys %$weights) {
                if ($chars[$i] eq $m) {
                    push @filtered, $weights->{$m};
                }
                else {
                    push @filtered, 0;
                }
            }
        }
       
        $max_col = ($max_col > $#filtered) ? $max_col : $#filtered+0;
        push @canvas, \@filtered;
    }
   
    # now fill out zeroes
    foreach my $x (0..$#canvas) {
        foreach my $y (0..$max_col) {
            $canvas[$x][$y] = 0 unless defined $canvas[$x][$y];
        }
    }
   
    close $ascii;
   
    my %obj = (
        'width' => $max_col+1, # width of the canvas
        'height' => @canvas+0, # height of the canvas
        'canvas' => \@canvas
    );
   
    return bless \%obj, $class;
}

# TODO!
sub new_from_layer {
    "die TODO: new from layer";
}

# TODO!
# e.g. this is a file w/ each line being x y value
sub new_from_file {
    "die TODO: new from layer";
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
    my $right = max($self->get_width(), $other->get_height() + $offsetX);
    my $bottom = min(0, $offsetY);
    my $top = max($self->get_width(), $other->get_height() + $offsetY);
    
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
            
            $new->{'canvas'}[$x][$y] = max(0, min(1, $subopt->($a_val, $b_val)));
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

1;