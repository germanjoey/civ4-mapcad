#!perl

use strict;
use warnings;
use lib 'lib';

use Civ4MapCad::State;
use Civ4MapCad::Processor qw(process_command);

our $max_players = 40;

our $state = Civ4MapCad::State->new;
#$SIG{'INT'} = sub {
#    check_save($state);
#};

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

sub check_save {
    my ($state) = @_;
    
    # XXX: this should just save a temp state or whatever
    if (!$state->{'saved'}) {
        print "Current state is not saved. Really exit?";
    }
    
    return 1;
}

