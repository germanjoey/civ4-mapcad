#!perl

use strict;
use warnings;
use lib 'lib';

use Config::General;
use Civ4MapCad::State;
use Civ4MapCad::Util qw(find_max_players);
use Civ4MapCad::Processor qw(process_command);

our %config = Config::General->new('def/config.cfg')->getall();

our $state = Civ4MapCad::State->new;
my $max = find_max_players($config{'mod'});

if ($max < 0) {
    print "ERROR: unknown mod set in def/config.cfg!\n";
    exit(1);
}

$config{'max_players'} = $max;

print "\n";
print "Welcome to Civ4 Map Cad!\n\n";
print "Type 'help' to see a command list.\n";
print "Type 'commandname --help' for more info on a particular command.\n";
print "\n";

process_command($state, 'run_script "def/init.civ4mc"');

while (1) {
    print "> ";
    my $command = <>;
    
    next unless $command =~ /\w/;
    process_command($state, $command);
}