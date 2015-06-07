#!perl

use strict;
use warnings;

use lib '../lib';

use Civ4MapCad::Map::Team;
my $team = Civ4MapCad::Map::Team->new();

my $filename = 'testTeam.CivBeyondSwordWBSave';

open (my $fhi, $filename) or die $!;
my $beginTeam = <$fhi>;
$team->parse($fhi);
close $fhi;

use Data::Dumper;
print Dumper $team;

open (my $fho, '>', "$filename.out") or die $!;
$team->write($fho);
close $fho;