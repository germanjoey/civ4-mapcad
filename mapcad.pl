#!perl

use strict;
use warnings;
use lib 'lib';

use Civ4MapCad::State;
use Civ4MapCad::Processor qw(process_command);

our %config;

$config{'max_players'} = 40;
$config{'difficulty'} = 'Monarch';

our $state = Civ4MapCad::State->new;

print "\n";
print "Welcome to Civ4 Map Cad!\n";
print "Create a new map with the command 'new name width height'\n";
print "type 'help' to see a command list; read commands.txt for more info about the commands.\n";
print "\n";

process_command($state, 'run_script "def/init.civ4mc"');

while (1) {
    print "> ";
    my $command = <>;
    
    next unless $command =~ /\w/;
    process_command($state, $command);
}
