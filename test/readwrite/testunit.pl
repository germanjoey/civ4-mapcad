#!perl

use strict;
use warnings;

use lib '../lib';

use Civ4MapCad::Map::Unit;
my $guard = Civ4MapCad::Map::Unit->new();

my $filename = 'testUnit.CivBeyondSwordWBSave';

open (my $fhi, $filename) or die $!;
my $beginUnit = <$fhi>;
$guard->parse($fhi);
close $fhi;

use Data::Dumper;
print Dumper $guard;

open (my $fho, '>', "$filename.out") or die $!;
$guard->write($fho);
close $fho;