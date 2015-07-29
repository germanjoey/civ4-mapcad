#!perl

use strict;
use warnings;
use lib 'lib';

use Config::General;
use Civ4MapCad::State;

use sigtrap qw(handler dump_log error-signals);

our %config = Config::General->new('def/config.cfg')->getall();
our $state = Civ4MapCad::State->new();

$config{'max_players'} = 0;
$config{'state'} = $state;

$SIG{'INT'} = sub { $main::config{'state'}->process_command('write_log'); exit(0) };
$SIG{__DIE__} = sub { $main::config{'state'}->process_command('write_log'); my $message = shift; die $message };

print "\n";
print "  Welcome to Civ4 Map Cad!\n\n";
print "  Type 'help' to see a command list.\n";
print "  Type 'commandname --help' for more info on a particular command.\n";

$state->process_command('run_script "def/init.civ4mc"');
$state->clear_log();

while (1) {
    print "> ";
    my $command = <>;
    
    next unless defined($command);
    next unless $command =~ /\w/;
    $state->process_command($command);
}

sub dump_log {
    $main::config{'state'}->process_command('write_log');
    my $message = shift;
    die $message;
}