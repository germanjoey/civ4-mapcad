#!perl

# perl 5.26 removed "." from @INC by default, so we've gotta re-add it.
BEGIN {
    if ($] >= 5.026) {
        use File::Spec;
        my $current_file = File::Spec->rel2abs(__FILE__);
        $current_file =~ s/\\\w+\.pl$//;
        chdir $current_file or die "Can't chdir to $current_file: $!\n";
        # safe now
        push @INC, '.';
    }
}

# this crazy jazz right here (the next 15 lines) splits STDOUT to a file
# method from here: http://stackoverflow.com/questions/387702/how-can-i-hook-into-perls-print
package IO::Override;
use base qw<Tie::Handle>;
use Symbol qw<geniosym>;

sub TIEHANDLE { return bless geniosym, __PACKAGE__ }

sub PRINTF { 
    shift;
    my $format = shift;
    
    open (my $log, '>>', 'output.txt');
    
    my @ok;
    foreach my $item (@_) {
        push @ok, $item if ref($item) eq '';
    }
    
    my @has_nl = grep { $_ =~ /\n/ } @ok;
    my $to_print = eval qq[sprintf '$format',] . join(', ', map { "'" . $_ . "'" } @ok);
    
    print $log $to_print;
    print $log "\n" unless @has_nl > 0;
    print $OLD_STDOUT $to_print;
    close $log;
}

sub PRINT { 
    shift;
    open (my $log, '>>', 'output.txt');
    
    my @ok;
    foreach my $item (@_) {
        push @ok, $item if ref($item) eq '';
    }
    
    my @has_nl = grep { $_ =~ /\n/ } @ok;
    print $log join('', @ok);
    print $log "\n" unless @has_nl > 0;
    print $OLD_STDOUT join('', @ok);
    close $log;
}

tie *PRINTOUT, 'IO::Override';
our $OLD_STDOUT = select( *PRINTOUT );

package main; 

use strict;
use warnings;

use lib 'lib';

# here's some crazy stuff for output/error logging
use sigtrap qw(handler dump_log error-signals);
tie *PRINTOUT, 'IO::Override';
our $OLD_STDOUT = select( *PRINTOUT );
$SIG{'INT'} = sub { $main::state->process_command('write_log'); exit(0) };
$SIG{__DIE__} = sub {
    my $message = shift; 
    open (my $error_log, '>>', "error.txt");
    print $error_log $message;
    close $error_log;
    $main::state->process_command('write_log');;
};
open (my $error_log, '>', "error.txt") or die $!;
open (my $output_log, '>', "output.txt") or die $!;

use Civ4MapCad;
our $state = Civ4MapCad->new();

print "\n";
print "  Welcome to Civ4 Map Cad!\n\n";
print "  Type 'help' to see a command list.\n";
print "  Type 'commandname --help' for more info on a particular command.\n";

$state->process_command('run_script "def/init.civ4mc"');
$state->clear_log();

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
    $main::state->process_command('write_log');
    my $message = shift;
    die $message;
}