#!perl

# this crazy jazz right here (the next 15 lines) splits STDOUT to a file
# method from here: http://stackoverflow.com/questions/387702/how-can-i-hook-into-perls-print
package IO::Override;
use base qw<Tie::Handle>;
use Symbol qw<geniosym>;

sub TIEHANDLE { return bless geniosym, __PACKAGE__ }
sub PRINT { 
    shift;
    open (my $log, '>>', 'output.txt');
    print $log join('', @_);
    print $OLD_STDOUT join('', @_ );
    close $log;
}

tie *PRINTOUT, 'IO::Override';
our $OLD_STDOUT = select( *PRINTOUT );

package main; 

use strict;
use warnings;

use lib 'lib';

use Config::General;
use Civ4MapCad::State;

use sigtrap qw(handler dump_log error-signals);

tie *PRINTOUT, 'IO::Override';
our $OLD_STDOUT = select( *PRINTOUT );

our %config = Config::General->new('def/config.cfg')->getall();
our $state = Civ4MapCad::State->new();

$config{'max_players'} = 0;
$config{'state'} = $state;

$SIG{'INT'} = sub { $main::config{'state'}->process_command('write_log'); exit(0) };
$SIG{__DIE__} = sub {
    my $message = shift; 
    open (my $error_log, '>>', "error.txt");
    print $error_log $message;
    close $error_log;
    $main::config{'state'}->process_command('write_log');;
};

print "\n";
print "  Welcome to Civ4 Map Cad!\n\n";
print "  Type 'help' to see a command list.\n";
print "  Type 'commandname --help' for more info on a particular command.\n";

$state->process_command('run_script "def/init.civ4mc"');
$state->clear_log();

open (my $error_log, '>', "error.txt") or die $!;
open (my $output_log, '>', "output.txt") or die $!;

close $error_log;
close $output_log;

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