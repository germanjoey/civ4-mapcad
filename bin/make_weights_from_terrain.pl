#!perl

use strict;
use warnings;

use lib 'lib';
use Config::General;

# THIS SHOULD BE CALLED FROM MAIN "civ4 mapcad" directory"

foreach my $terrain_filename (glob('def/*.terrain')) {
    next if $terrain_filename =~ /base_terrain/;
    my %terrain = Config::General->new($terrain_filename)->getall();
   
    my %groups;
    foreach my $def_name (keys %terrain) {
        my ($type, $resource_name) = $def_name =~ /^(\w+)_([a-z]+)/;
        next if $type eq 'bare';
        
        $groups{$resource_name} = [] unless exists $groups{$resource_name};
        push @{ $groups{$resource_name} }, $def_name;
    }
    
    my $weight_filename = $terrain_filename;
    $weight_filename =~ s/\.terrain/.civ4mc/;
    open (my $weight_file, '>', $weight_filename) or die $!;
    
    my @group_names = sort keys %groups;
    foreach my $group_name (@group_names) {
        make_weight_table($weight_file, $group_name, 0, @{ $groups{$group_name} });
    }

    my ($type) = $weight_filename =~ /\.\.\/def\/(\w+)/;
    make_weight_table($weight_file, $type, 1, @group_names);
    make_weight_table($weight_file, $type, 0, map { "bare_$_" } @group_names);
    
    close $weight_file;
    $weight_filename =~ s/^\.\.\///;
    print qq[run_script "$weight_filename"\n];
}

sub make_weight_table {
    my ($weight_file, $final_name, $from_weight, @groups) = @_;
    
    my $percent_step = 1/@groups;
    my $percent = 1;
    my $p = ($from_weight) ? '%' : '';
    
    print $weight_file "new_weight_table ";
    foreach my $perm (sort @groups) {
        $percent = sprintf "%4.2f", $percent - $percent_step;
        $percent = "0.00" if $percent < 0.05;
        print $weight_file ">= $percent => $p$perm,\n";
        print $weight_file "                 ";
    }
    
    print $weight_file "=> \%$final_name\n\n";
}