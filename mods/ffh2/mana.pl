#!perl

use strict;
use warnings;

my @mana = qw(BONUS_MANA_ICE BONUS_MANA_LIFE BONUS_MANA_SUN BONUS_MANA_FIRE BONUS_MANA_EARTH BONUS_MANA_DEATH BONUS_MANA_AIR BONUS_MANA_BODY BONUS_MANA_CHAOS BONUS_MANA_ENCHANTMENT BONUS_MANA_ENTROPY BONUS_MANA_LAW BONUS_MANA_METAMAGIC BONUS_MANA_MIND BONUS_MANA_NATURE BONUS_MANA_SPIRIT BONUS_MANA_WATER BONUS_MANA_SHADOW);

foreach my $mana (@mana) {
    my $tag = lc $mana;
    $tag =~ s/bonus/bare/;
    $tag =~ s/mana_//;
    $tag = $tag . '_mana';
    print "<$tag>\n    BonusType=$mana\n</$tag>\n";
}