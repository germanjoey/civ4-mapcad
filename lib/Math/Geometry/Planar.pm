#
# Copyright (c) 2002 Danny Van de Pol - Alcatel Telecom Belgium
# danny.vandepol@alcatel.be
#
# Free usage under the same Perl Licence condition.
#

package Math::Geometry::Planar;

#
# NOTE!!! This is a version of Math::Geometry::Planar that has had most of its functionality cut away
# I've done this in order to avoid requiring the 'Math::Geometry::Planar::GPC' module as a dependency,
# which requires XS. 
#
# Please see here for the full code:
# http://cpansearch.perl.org/src/DVDPOL/Math-Geometry-Planar-1.18-withoutworldwriteables/Planar.pm
#

$VERSION   = '1.18';

use vars qw(
            $VERSION
            @ISA
            @EXPORT
            @EXPORT_OK
            $precision
           );

use strict;
use Carp;
use POSIX;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT_OK = qw(Determinant DotProduct CrossProduct
                SegmentIntersection IsInsidePolygon IsSimplePolygon
               );
               
require 5.005;
$precision = 7;
my $delta = 10 ** (-$precision);

################################################################################
#  
#  The determinant for the matrix  | x1 y1 |
#                                  | x2 y2 |
#
# args : x1,y1,x2,y2
#
sub Determinant {
  my ($x1,$y1,$x2,$y2) = @_;
  return ($x1*$y2 - $x2*$y1);
}

################################################################################
#
# vector dot product
# calculates dotproduct vectors p1p2 and p3p4
# The dot product of a and b  is written as a.b and is
# defined by a.b = |a|*|b|*cos q 
#
# args : reference to an array with 4 points p1,p2,p3,p4 defining 2 vectors
#        a = vector p1p2 and b = vector p3p4
#        or
#        reference to an array with 3 points p1,p2,p3 defining 2 vectors
#        a = vector p1p2 and b = vector p1p3
#
sub DotProduct {
  my $pointsref = $_[0];
  my @points = @$pointsref;
  my (@p1,@p2,@p3,@p4);
  if (@points == 4) {
    @p1 = @{$points[0]};
    @p2 = @{$points[1]};
    @p3 = @{$points[2]};
    @p4 = @{$points[3]};
  } elsif (@points == 3) {
    @p1 = @{$points[0]};
    @p2 = @{$points[1]};
    @p3 = @{$points[0]};
    @p4 = @{$points[2]};
  } else {
    carp("Need 3 or 4 points for a dot product");
    return;
  }
  return ($p2[0]-$p1[0])*($p4[0]-$p3[0]) + ($p2[1]-$p1[1])*($p4[1]-$p3[1]);
}
#########################

#######################################################
#
# returns vector cross product of vectors p1p2 and p1p3
# using Cramer's rule
#
# args : reference to an array with 3 points p1,p2 and p3
#
sub CrossProduct {
  my $pointsref = $_[0];
  my @points = @$pointsref;
  if (@points != 3) {
    carp("Need 3 points for a cross product");
    return;
  }
  my @p1 = @{$points[0]};
  my @p2 = @{$points[1]};
  my @p3 = @{$points[2]};
  my $det_p2p3 = Determinant($p2[0], $p2[1], $p3[0], $p3[1]);
  my $det_p1p3 = Determinant($p1[0], $p1[1], $p3[0], $p3[1]);
  my $det_p1p2 = Determinant($p1[0], $p1[1], $p2[0], $p2[1]);
  return ($det_p2p3-$det_p1p3+$det_p1p2);
}

#
# The winding number method has been cused here.  Seems to
# be the most accurate one and, if well written, it matches
# the performance of the crossing number method.
# The winding number method counts the number of times a polygon
# winds around the point.  If the result is 0, the points is outside
# the polygon.
#
# args: reference to polygon object
#       reference to a point
#
sub IsInsidePolygon {
  my ($pointsref,$pointref) = @_;
  my @points = @$pointsref;
  if (@points < 3) { # polygon should at least have 3 points ...
    carp("Can't run inpolygon: polygon should have at least 3 points");
    return;
  }
  if (! $pointref) {
    carp("Can't run inpolygon: no point entered");
    return;
  }
  my @point = @$pointref;
  my $wn;  # thw winding number counter
  for (my $i = 0 ; $i < @points ; $i++) {
    my $cp = CrossProduct([$points[$i-1],$points[$i],$pointref]);
    # if colinear and in between the 2 points of the polygon
    # segment, it's on the perimeter and considered inside
    if ($cp == 0) {
      if (
          ((($points[$i-1][0] <= $point[0] &&
             $point[0] <= $points[$i][0])) ||
           (($points[$i-1][0] >= $point[0] &&
             $point[0] >= $points[$i][0])))
          &&
          ((($points[$i-1][1] <= $$pointref[1] &&
             $point[1] <= $points[$i][1])) ||
           (($points[$i-1][1] >= $point[1] &&
             $point[1] >= $points[$i][1])))
         ) {
         return 1;
       }
    }
    if ($points[$i-1][1] <= $point[1]) { # start y <= P.y
      if ($points[$i][1] > $point[1]) {  # // an upward crossing
        if ($cp > 0) {
          # point left of edge
          $wn++;                         # have a valid up intersect
        }
      }
    } else {                             # start y > P.y (no test needed)
      if ($points[$i][1] <= $point[1]) { # a downward crossing
        if ($cp < 0) {
          # point right of edge
          $wn--;                         # have a valid down intersect
        }
      }
    }
  }
  return $wn;
}

################################################################################
#
# Brute force attack:
# just check intersection for every segment versus every other segment
# so for a polygon with n ponts this will take n**2 intersection calculations
# I added a few simple improvements: to boost speed:
#   - don't check adjacant segments
#   - don't check against 'previous' segments (if we checked segment x versus y,
#     we don't need to check y versus x anymore)
# Results in (n-2)*(n-1)/2 - 1 checks  which is close to n**2/2 for large n
#
# make sure to remove colinear points first before calling perimeter
# (I prefer not to include the call to cleanup)
#
# args: reference to polygon or contour object
#       (a contour is considered to be simple if all it's shapes are simple)
#
sub IsSimplePolygon {
  my ($pointsref) = @_;
  my @points = @$pointsref;
  return 1 if (@points < 4); # triangles are simple polygons ...
  for (my $i = 0 ; $i < @points-2 ; $i++) {
    # check versus all next non-adjacant edges
    for (my $j = $i+2 ; $j < @points ; $j++) {
      # don't check first versus last segment (adjacant)
      next if ($i == 0 && $j == @points-1);
      if (SegmentIntersection([$points[$i-1],$points[$i],$points[$j-1],$points[$j]])) {
        return 0;
      }
    }
  }
  return 1;
}

################################################################################
#
# calculate intersection point of 2 line segments
# returns false if segments don't intersect
# The theory:
#
#  Parametric representation of a line
#    if p1 (x1,y1) and p2 (x2,y2) are 2 points on a line and
#       P1 is the vector from (0,0) to (x1,y1)
#       P2 is the vector from (0,0) to (x2,y2)
#    then the parametric representation of the line is P = P1 + k (P2 - P1)
#    where k is an arbitrary scalar constant.
#    for a point on the line segement (p1,p2)  value of k is between 0 and 1
#
#  for the 2 line segements we get
#      Pa = P1 + k (P2 - P1)
#      Pb = P3 + l (P4 - P3)
#
#  For the intersection point Pa = Pb so we get the following equations
#      x1 + k (x2 - x1) = x3 + l (x4 - x3)
#      y1 + k (y2 - y1) = y3 + l (y4 - y3)
#  Which using Cramer's Rule results in
#          (x4 - x3)(y1 - y3) - (y4 - x3)(x1 - x3)
#      k = ---------------------------------------
#          (y4 - y3)(x2 - x1) - (x4 - x3)(y2 - y1)
#   and
#          (x2 - x1)(y1 - y3) - (y2 - y1)(x1 - x3)
#      l = ---------------------------------------
#          (y4 - y3)(x2 - x1) - (x4 - x3)(y2 - y1)
#
#  Note that the denominators are equal.  If the denominator is 9,
#  the lines are parallel.  Intersection is detected by checking if
#  both k and l are between 0 and 1.
#
#  The intersection point p5 (x5,y5) is:
#     x5 = x1 + k (x2 - x1)
#     y5 = y1 + k (y2 - y1)
#
# 'Touching' segments are considered as not intersecting
#
# args : reference to an array with 4 points p1,p2,p3,p4
#
sub SegmentIntersection {
  my $pointsref = $_[0];
  my @points = @$pointsref;
  if (@points != 4) {
    carp("SegmentIntersection needs 4 points");
    return;
  }
  my @p1 = @{$points[0]}; # p1,p2 = segment 1
  my @p2 = @{$points[1]};
  my @p3 = @{$points[2]}; # p3,p4 = segment 2
  my @p4 = @{$points[3]};
  my @p5;
  my $n1 = Determinant(($p3[0]-$p1[0]),($p3[0]-$p4[0]),($p3[1]-$p1[1]),($p3[1]-$p4[1]));
  my $n2 = Determinant(($p2[0]-$p1[0]),($p3[0]-$p1[0]),($p2[1]-$p1[1]),($p3[1]-$p1[1]));
  my $d  = Determinant(($p2[0]-$p1[0]),($p3[0]-$p4[0]),($p2[1]-$p1[1]),($p3[1]-$p4[1]));
  if (abs($d) < $delta) {
    return 0; # parallel
  }
  if (!(($n1/$d < 1) && ($n2/$d < 1) &&
        ($n1/$d > 0) && ($n2/$d > 0))) {
    return 0;
  }
  $p5[0] = $p1[0] + $n1/$d * ($p2[0] - $p1[0]);
  $p5[1] = $p1[1] + $n1/$d * ($p2[1] - $p1[1]);
  return \@p5; # intersection point
}

1;