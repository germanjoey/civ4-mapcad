package Civ4MapCad::Weight;
 
use strict;
use warnings;

# tableref is a reference to $state's tableref, which we need to lookup nested weights
sub new_from_pairs {
    my ($class, $tableref, @pairs) = @_;
 
    my %obj = (
        'tableref' => $tableref,
        'pairs' => \@pairs,
    );
   
    return bless \%obj, $class;
}

1;