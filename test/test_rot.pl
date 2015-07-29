#!perl

use strict;
use warnings;

use lib 'lib';
use Data::Dumper;
use POSIX qw(ceil);
use Algorithm::Line::Bresenham qw(line);
use List::Util qw(min);
use Civ4MapCad::Rotator qw(rotate_grid);

my $width = 20;
my $height = 20;
my $angle = 60;

my @arr = setup_input($width, $height);

my ($new_grid, $new_width, $new_height);
my ($move_x, $move_y, $result_angle1, $result_angle2) = (0,0,0,0);
($new_grid, $new_width, $new_height, $move_x, $move_y, $result_angle1, $result_angle2) = rotate_grid(\@arr, $width, $height, $angle, 1);

print "\n\n$new_width, $new_height, $move_x, $move_y, $result_angle1, $result_angle2\n\n";

foreach my $y (0..($new_height-1)) {
    foreach my $x (0..($new_width-1)) {
        my $p = $new_grid->[$x][$new_height-1-$y];
        print (defined($p) ? $p : ' ');
    }
    print "\n";
}

sub setup_input {
    my @arr;
    foreach my $x (0..($width-1)) {
        $arr[$x] = [];
        foreach my $y (0..($height-1)) {
            $arr[$x][$y] = 'x';
            $arr[$x][$y] = '*' if $y == 0;
            $arr[$x][$y] = '*' if $y == ($height-1);
        }
    }

    $arr[13][13] = '1';
    $arr[14][13] = '2';
    $arr[15][13] = '3';
    $arr[13][14] = '4';
    $arr[14][14] = '5';
    $arr[15][14] = '6';
    $arr[13][15] = '7';
    $arr[14][15] = '8';
    $arr[15][15] = '9';

    foreach my $y (0..($height-1)) {
        foreach my $x (0..($width-1)) {
        #     print $arr[$x][$height-1-$y];
        }
        # print "\n";
    }
    return @arr;
}

