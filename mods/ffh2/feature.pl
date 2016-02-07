#!perl

use strict;
use warnings;

my @features = qw(FEATURE_FLAMES FEATURE_BLIZZARD FEATURE_TORMENTED_SOULS FEATURE_DOOR_WEST_CLOSED FEATURE_DOOR_WEST_OPEN FEATURE_DOOR_NORTH_CLOSED FEATURE_DOOR_NORTH_OPEN FEATURE_WALLS FEATURE_FOREST_NEW FEATURE_FOREST_ANCIENT FEATURE_VOLCANO  FEATURE_FOREST_BURNT FEATURE_SCRUB);

foreach my $feat (@features) {
    my $tag = lc $feat;
    $tag =~ s/feature/bare/;
    print "<$tag>\n    FeatureType=$feat, FeatureVariety=0\n</$tag>\n";
}
