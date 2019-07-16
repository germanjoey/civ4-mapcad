#!perl

use strict;
use warnings;
use lib 'lib';

use IO::String;
use Symbol;

use Config::General;
use Civ4MapCad;

# THIS SHOULD BE CALLED FROM MAIN "civ4 mapcad" directory"

our %config = Config::General->new('def/config.cfg')->getall();

our $state = Civ4MapCad->new();
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

print $doc "# Command List\n";
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
    
    print $doc "## $command\n";
    
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
            elsif ($line =~ /^Flag/i) {
                print $doc "\n";
                print $doc "\n    $line ";
                print $doc shift @lines;
                print $doc " ";
                print $doc shift @lines;
                print $doc "\n    ";
                
                while (1) {
                    my $line = shift @lines;
                    
                    if ($line =~ /^Description/i) {
                        unshift @lines, $line;
                        last;
                    }
                    
                    if ($line =~ /^\-\-/) {
                        print $doc "\n    ";
                    }
                    
                    print $doc $line;
                    print $doc " ";
                }
            }

            elsif ($line =~ /^Speci/i) {
                print $doc "\n";
                print $doc "\n    $line ";
                print $doc shift @lines;
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
    #@lines = grep { $_ =~ /\w/ } @lines;
    @lines = map { ($_ eq '') ? "\n\n" : $_ } @lines;
    my $rest = join (" ", @lines);
    $rest =~ s/\n +/\n/g;
    print $doc $rest;
    print $doc "\n\n" unless $i == $#commands;
}