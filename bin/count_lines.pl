#!perl

use strict;
use warnings;

use File::Find;
my %line_count;
my %count;

find sub {
    return $File::Find::prune = 1 if $_ eq '.git';
    return $File::Find::prune = 1 if $_ eq 'input';
    return $File::Find::prune = 1 if $_ eq 'output';
    return $File::Find::prune = 1 if $_ eq 'jquery-ui-1.11.4';
    return $File::Find::prune = 1 if $_ eq 'Algorithm';
    return $File::Find::prune = 1 if $_ eq 'Math';
    return $File::Find::prune = 1 if $_ eq 'Config';
    return $File::Find::prune = 1 if $_ eq 'Exporter';
    return $File::Find::prune = 1 if $_ eq 'Text';
    return $File::Find::prune = 1 if $_ eq 'i';
    
    return if $_ =~ /CivBeyondSwordWBSave$/;
    return if $_ =~ /alloc$/;
    return if $_ =~ /jpg$/;
    return if $_ =~ /gif$/;
    return if $_ =~ /png$/;
    return if $_ =~ /xcf$/;
    return if $_ =~ /zip$/;
    return if $_ =~ /txt$/;
    return if $_ =~ /html$/;
    return if $_ =~ /out$/;
    return if $_ =~ /debug$/;
    return if $_ =~ /gitattributes$/;
    return if -d;
    
    my ($type) = $_ =~ /(\w+)$/;
    
    open (my $file, $_) or die $!;
    my @lines = <$file>;
    close $file;
    
    $line_count{$type} += @lines;
    $count{$type} = 0 unless exists $count{$type};
    $count{$type} ++;
}, ".";

print "\n";

my $total = 0;
for my $type (sort keys %count) {
    print "$count{$type} items of type $type, totalling $line_count{$type} lines.\n";
    next if $type eq 'md';
    $total += $line_count{$type};
}

print "\nTotal lines of code (not counting md): $total\n";