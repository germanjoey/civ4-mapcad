package Civ4MapCad::Object::Mask;
 
use strict;
use warnings;

use List::Util qw(min max);
use Civ4MapCad::Ascii qw(import_ascii_mask export_ascii_mask);

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