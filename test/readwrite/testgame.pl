#!perl

use strict;
use warnings;

use lib '../../lib';

use Civ4MapCad::Map::Game;
my $game = Civ4MapCad::Map::Game->new();

my $filename = 'testGame.CivBeyondSwordWBSave';

open (my $fhi, $filename) or die $!;
my $beginGame = <$fhi>;
$game->parse($fhi);
close $fhi;

use Data::Dumper;
print Dumper $game;

open (my $fho, '>', "$filename.out") or die $!;
$game->write($fho);
close $fho;