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
    $command =~ s/;$//;
    return 0 if $command =~ /^#/;
    
    $command =~ s/\=\>/ => /g;
    $state->{'current_line'} = $command;
    
    my ($command_name, @params) = split ' ', $command;    
    $command_name = lc $command_name;
    
    # TODO: create a "return" command to allow run_script to return a result
    if ($command_name eq 'run_script') {
        if (@params != 1) {
            my $n = @params;
            $state->report_error("run_script uses only 1 parameter, but recieved $n. Please see commands.txt for more info.");
        }
    
        if ($params[0] !~ /^"[^"]+"$/) {
            $state->report_error("run_script requires a single string argument containing the path to the script to run.");
        }
        
        $params[0] =~ s/\"//g;
        
        $state->in_script();
        my $ret = process_script($state, @params);
        $state->off_script();
        
        if ($state->is_off_script()) {
            $state->add_log($command);
        }
        
        return $ret;
    }
    
    elsif ($command_name eq 'exit') {
        exit(0);
    }
    
    elsif ($command_name eq 'help') {
        my @com_list = keys %$repl_table;
        push @com_list, ('exit', 'help', 'run_script');
        @com_list = sort @com_list;
        
        if (@params == 1) {
            if ($params[0] eq '--help') {
                print "\n...\n\n";
                return -1;
            }
        
            @com_list = grep { $_ =~ /$params[0]/ } @com_list;
        }
    
        my $com = join ("\n    ", @com_list);
        print qq[\nAvailable commands are:\n\n    $com\n\n];
        print qq[You can filter this list with a phrase, e.g. "help weight" to show all commands with "weight" in their name.\n\n] if @params == 0;
        print qq[For more info about a specific command, type its name plus --help, e.g. "evaluate_weight --help".\n\n];
        return 1;
    }
    
    elsif (exists $repl_table->{$command_name}) {
        my $ret = $repl_table->{$command_name}->($state, @params);
        
        if ($state->is_off_script()) {
            $state->add_log($command);
        }
        
        return $ret;
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
    
    my @filtered_lines;
    my $current_line = '';
    foreach my $i (0 .. $#lines) {
        my $line = $lines[$i];
        chomp $line;
        
        $line =~ s/#.*//; # strip comments
        next unless $line =~ /\w/;
        
        if ($line =~ /^\s|\t/) {
            $line =~ s/^[\t\s]+//;
            $current_line = $current_line . " " . $line;
            next;
        }
        elsif ($current_line ne '') {
            push @filtered_lines, [$i, $current_line];
            $current_line = '';
        }
        
        $current_line = $line;
    }
    
    push @filtered_lines, [$#lines, $current_line] if $current_line ne '';
    
    foreach my $l (@filtered_lines) {
        my ($i, $line) = @$l;
        
        my $ret = process_command($state, $line);
        
        if ($ret == -1) {
            print " ** inducing early script exit for script '$script_path' due to error on line '$i'...\n\n";
            return -1;
        }
    }
    
    return 1;
}

1;
