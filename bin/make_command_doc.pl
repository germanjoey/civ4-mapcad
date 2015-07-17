#!perl

use strict;
use warnings;
use lib 'lib';

use IO::String;
use Symbol;

use Config::General;
use Civ4MapCad::State;
use Civ4MapCad::Util qw(find_max_players);


our %config = Config::General->new('def/config.cfg')->getall();

our $state = Civ4MapCad::State->new();
my $max = find_max_players($config{'mod'});

if ($max < 0) {
    print "ERROR: unknown mod set in def/config.cfg!\n";
    exit(1);
}

$config{'max_players'} = $max;
$config{'state'} = $state;

$state->process_command('run_script "def/init.civ4mc"');
$state->clear_log();

my $captured_output;
close STDOUT;
open(STDOUT, ">", \$captured_output);
$state->process_command('help');

my @lines = split "\n", $captured_output;
shift @lines for (1..3);
pop @lines for (1..7);
my @commands = map { $_ =~ s/\s//g; $_ } sort @lines;

open (my $doc, '>', 'doc/Commands.md') or die $!;
foreach my $i (0..$#commands) {
    my $command = $commands[$i];
    warn "processing $command\n";
    print $doc "##$command\n";
    
    my $captured_output;
    close STDOUT;
    open(STDOUT, ">", \$captured_output);
    $state->process_command("$command --help");
    
    my @lines = split "\n", $captured_output;
    foreach my $line (@lines) {
        substr($line, 0, 2) = '';
    }
    
    print $doc join("\n", @lines);
    print $doc "\n\n" unless $i == $#commands;
}