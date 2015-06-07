package Civ4MapCad::Processor;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(process_command);

use Civ4MapCad::Commands;
use Civ4MapCad::Util qw(report_error);
our $repl_table = create_dptable Civ4MapCad::Commands; 

sub process_command {
    my ($state, $command) = @_;
    
    chomp $command;
    $command =~ s/^\s*//;
    $command =~ s/\s*$//;
    $command = lc $command;
    return 0 if $command =~ /^#/;
    
    $command =~ s/\=\>/ => /g;
    $state->{'current_line'} = $command;
    
    my ($command_name, @params) = split ' ', $command;
    
    if ($command_name eq 'run_script') {
        if (@params != 1) {
            my $n = @params;
            $state->report_error("run_script uses only 1 parameter, but recieved $n. Please see commands.txt for more info.");
        }
        return process_script($state, @params);
    }
    
    elsif ($command_name eq 'exit') {
        exit(0);
    }
    
    elsif ($command_name eq 'help') {
        my $com = join ("\n  ", sort (keys %$repl_table));
        print "\nAvailable commands are:\n  $com\nPlease see commands.txt for more info on each command.\n\n";
        return 1;
    }
    
    elsif (exists $repl_table->{$command_name}) {
        return $repl_table->{$command_name}->($state, @params);
    }
    
    else {
        $state->report_error("unknown command '$command_name'");
        return -1;
    }
}

sub process_script {
    my ($state, $script_path) = @_;
    
    # TODO: put in a call stack to prevent recursive script loads
    
    my $ret = open (my $script, $script_path);
    unless ($ret) {
        $state->report_error("could not load script '$script_path': $!");
        return;
    }
    
    my @lines = <$script>;
    close $script;
    
    foreach my $i (@lines) {
        my $line = $lines[$i];
        
        my $ret = process_command($state, $line);
        
        if ($ret == -1) {
            print " ** inducing early script exit for script '$script_path' due to error on line '$i'...\n\n";
            return -1;
        }
    }
    
    return 1;
}

1;
