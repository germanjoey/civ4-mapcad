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

print $doc "#Command List\n";
print $doc "This file is auto-generated from bin/make_command_doc.pl from the in-program help text for each command.\n\n";

foreach my $i (0..$#commands) {
    my $command = $commands[$i];
    warn "processing $command\n";
    
    # capture STDOUT to a string. we have to do this inside the loop because otherwise
    # stdout captures a shitload of null characters for some reason
    my $captured_output;
    close STDOUT;
    open(STDOUT, ">", \$captured_output);
    $state->process_command("$command --help");
    
    my @lines = split "\n", $captured_output;
    
    print $doc "##$command\n";
    
    # strip out indent
    foreach my $line (@lines) {
        chomp $line;
        $line =~ s/^\s+//;
    }
    
    # first strip out the header.
    while (1) {
        my $line = shift @lines;
        if (@lines == 0) {
            warn "NO COMMAND FORMAT FOUND FOR $command";
            die;
        }
        if ($line =~ /Command Format/i) {
            last;
        }
    }
    
    print $doc "    ";
    
    # indent the command format so it shows up as code, and then bail when we get to the help text
    my $already_specified = 0;
    while (1) {
        my $line = shift @lines;
        if (@lines == 0) {
            warn "NO DESCRIPTION FOUND FOR $command";
            die;
        }
        next unless $line =~ /\w/;
        
        if ($line =~ /^Description/i) {
            print $doc "\n" unless $already_specified;
            print $doc "\n";
            last;
        }
        else {
            if ($line =~ /^param/) {
                print $doc "\n      $line";
            }
            elsif (($line =~ /^Flag/i) or ($line =~ /^Speci/i)) {
                print $doc "\n" unless $already_specified == 1;
                print $doc "\n    $line\n";
                $already_specified = 1;
            }
            else {
                if ($already_specified) {
                    print $doc "    $line\n";
                }
                else {
                    print $doc "$line ";
                }
                    
            }
        }
    }
    
    # join the rest of the description
    @lines = grep { $_ =~ /\w/ } @lines;
    print $doc join (" ", @lines);
    print $doc "\n\n" unless $i == $#commands;
}