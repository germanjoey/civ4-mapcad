#!perl
 
use strict;
use warnings;
 
my @array;
my %state = (
    'width' => 4,
    'height' => 6,
    'startX' => 5,
    'startY' => 5
);
 
my $rows = 11;
my $cols = 11;
 
require 'Shapes/Square.pm';

do {
    no strict 'refs';
    *{"Civ4MapCad::Shapes::Square::gen"} = \&gen;
};

require 'Shapes/Circle.pm';
 
foreach my $x (0..$rows-1) {
    $array[$x] = [];
    foreach my $y (0..$cols-1) {
        my $sub;
        do {
            no strict 'refs';
            $sub = *{"Civ4MapCad::Shapes::Square::gen"};
        };
        my $res = $sub->(\%state, $x, $y);
        $array[$x][$y] = ($res > 0.5) ? '.' : ' ';
    }
}
 
foreach my $x (0..$rows-1) {
    print "\n";
    foreach my $y (0..$cols-1) {
        print $array[$x][$y];
    }
}
