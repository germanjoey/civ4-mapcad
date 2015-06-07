#!perl

use strict;
use warnings;

use lib '../../lib';

use Civ4MapCad::Map::Player;
my $player = Civ4MapCad::Map::Player->new();

my $filename = 'testPlayer.CivBeyondSwordWBSave';

open (my $fhi, $filename) or die $!;
my $beginPlayer = <$fhi>;
$player->parse($fhi);
close $fhi;

use Data::Dumper;
print Dumper $player;

open (my $fho, '>', "$filename.out") or die $!;
$player->write($fho);
close $fho;