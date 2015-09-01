#!perl

use strict;
use warnings;

use List::Util qw(min max);

foreach my $i (0..100) {
    print "\n" if ($i%4) == 0;
    printf ".o%d { opacity:%4.2f; } ", $i, $i/100;
}

print "\n\n";

my %seen;
foreach my $i (0..15) {
    foreach my $j (0..15) {
        print "\n" if ($j%4) == 0;
        my $rcode = sprintf "%02x", 16*$i + 8;
        my $bcode = sprintf "%02x", 16*(15-$j) + 8;
        
        if (exists $seen{"$rcode$bcode"}) {
            warn "WARNING: $rcode$bcode already seen!\n";
        }
        $seen{"$rcode$bcode"} = 1;
        
        printf ".p%s%s { background-color: #%s00%s; } ", $rcode, $bcode, $rcode, $bcode;
    }
    print "\n";
}