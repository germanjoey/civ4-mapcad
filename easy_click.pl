#!perl

use strict;
use warnings;

use lib 'lib';
use Civ4MapCad;

print qq[\n];
print qq[  Welcome to Civ4MC's easy-click mode! This script will look for a map named\n];
print qq[  "map.CivBeyondSwordWBSave" in this directory, and then apply the "fix_map",\n];
print qq[  "export_sims", and "balance_report" commands on it. Your output map and sims\n];
print qq[  will be in the output folder, renamed to "map_fixed.CivBeyondSwordWBSave".\n\n];
print qq[  Press enter to begin.\n  ];
my $initial_confirm = <>;

if (! -e 'map.CivBeyondSwordWBSave') {
    print "** ERROR: Can't find a file named 'map.CivBeyondSwordWBSave' in this directory!\n";
    print "\nPress enter to exit.\n  ";
    my $final_confirm = <>;
    exit();
}

mkdir 'output' unless -e 'output';
open (my $error_log, '>', "error.txt") or die $!;
open (my $output_log, '>', "output.txt") or die $!;

our $state = Civ4MapCad->new();
our $exit_ok = 0;

$SIG{'INT'} = sub { $main::state->process_command('write_log'); exit(0) };
$SIG{__DIE__} = sub {
    my $message = shift; 
    open (my $error_log, '>>', "error.txt");
    print $error_log $message;
    close $error_log;
    $main::state->process_command('write_log');
    
    if ($exit_ok == 1) {
        print "\nUnknown error, see \"error.txt\" for details. Press press enter to exit.\n  ";
        my $exit_confirm = <>;
        exit();
    }
};

$state->process_command('run_script "def/init.civ4mc"');
$state->clear_log();

close $error_log;
close $output_log;

my %m;
my @mods = map { /mods\/(.+)$/ } grep { -d $_ } glob("mods/*");
@m{@mods} = (1) x @mods;

$state->process_command('list_mods');
print "  Enter the name of the mod (no quotes) that you'd like to use for this map, or\n";
print "  else just press enter to begin with the default: ";

while (1) {
    my $mod = <>;
    $mod =~ s/^\s+//;
    $mod =~ s/\s+$//;
    $mod =~ s/\s*\"\s*//g;
    $mod = lc $mod;
    
    if ($mod eq '') {
        print qq[\n  Starting process using default mod: "$state->{'mod'}".\n\n];
        last;
    }
    elsif (exists $m{$mod}) {
        print qq[\n  Starting process using "$mod".\n\n];
        $state->process_command(qq[set_mod "$mod"]);
        last;
    }
    else {
        print qq[\n  Unknown mod "$mod", please try again: ];
    }
}

$exit_ok = 1;

$state->process_command(qq[import_group "map.CivBeyondSwordWBSave" => \$map]);
$state->process_command(qq[fix_map \$map => \$map_fixed]);
$state->process_command(qq[export_sims \$map_fixed]);
$state->process_command(qq[balance_report \$map_fixed]);
unlink "output/map_fixed.map.CivBeyondSwordWBSave";
$state->clear_log();
    
print "\nPress enter to exit.\n  ";
my $final_confirm = <>;
