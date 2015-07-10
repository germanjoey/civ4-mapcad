package Civ4MapCad::State;

use strict;
use warnings;

use Text::Wrap qw(wrap);

use Civ4MapCad::Commands;
our $repl_table = create_dptable Civ4MapCad::Commands; 

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($spec) = @_;
    
    my $obj = {
        'output_dir' => './',
        'variables' => {},
        'group' => {},
        'shape' => {},
        'shape_param' => {},
        'mask' => {},
        'terrain' => {},
        'in_script' => 0,
        'log' => []
    };
    
    return bless $obj, $class;
}

sub process_command {
    my ($self, $command) = @_;
    
    chomp $command;
    $command =~ s/^\s*//;
    $command =~ s/\s*$//;
    $command =~ s/;$//;
    return 0 if $command =~ /^#/;
    
    $command =~ s/\=\>/ => /g;
    $self->{'current_line'} = $command;
    
    my ($command_name, @params) = split ' ', $command;    
    $command_name = lc $command_name;
    
    # TODO: create a "return" command to allow run_script to return a result
    if ($command_name eq 'run_script') {
        if (@params != 1) {
            my $n = @params;
            $self->report_error("run_script uses only 1 parameter, but recieved $n. Please see commands.txt for more info.");
        }
    
        if ($params[0] !~ /^"[^"]+"$/) {
            $self->report_error("run_script requires a single string argument containing the path to the script to run.");
        }
        
        $params[0] =~ s/\"//g;
        
        $self->in_script();
        my $ret = $self->process_script(@params);
        $self->off_script();
        
        if ($self->is_off_script()) {
            $self->add_log($command);
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
        
            if (@com_list == 0) {
                print qq[\n* No commands found that match query '$params[0]'.\n\n];
            }
        }
        
        my $com = join ("\n    ", @com_list);
        print qq[\nAvailable commands are:\n\n    $com\n\n];
        print qq[You can filter this list with a phrase, e.g. "help weight" to show all commands with "weight" in their name.\n\n] if @params == 0;
        print qq[For more info about a specific command, type its name plus --help, e.g. "evaluate_weight --help".\n\n];
        
        return 1;
    }
    
    elsif (exists $repl_table->{$command_name}) {
        my $ret = $repl_table->{$command_name}->($self, @params);
        
        if ($self->is_off_script()) {
            $self->add_log($command);
        }
        
        return $ret;
    }
    
    else {
        $self->report_error("unknown command '$command_name'");
        return -1;
    }
}

sub process_script {
    my ($self, $script_path) = @_;
    
    # TODO: put in a call stack to prevent recursive script loads
    
    my $ret = open (my $script, $script_path);
    
    unless ($ret) {
        $self->report_error("could not load script '$script_path': $!");
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
        
        my $ret = $self->process_command($line);
        
        if ($ret == -1) {
            print " ** inducing early script exit for script '$script_path' due to error on line '$i'...\n\n";
            return -1;
        }
    }
    
    return 1;
}

sub in_script {
    my ($self) = @_;
    $self->{'in_script'} ++;
}

sub off_script {
    my ($self) = @_;
    $self->{'in_script'} --;
}

sub is_off_script {
    my ($self) = @_;
    return ($self->{'in_script'} == 0);
}

sub add_log {
    my ($self, $command) = @_;
    push @{ $self->{'log'} }, $command;
}

sub get_log {
    my ($self) = @_;
    return @{ $self->{'log'} };
}

sub get_output_dir {
    my ($self) = @_;
    return $self->{'output_dir'};
}

sub set_output_dir {
    my ($self, $dir) = @_;
    $self->{'output_dir'} = $dir;
}

sub get_shape_params {
    my ($self, $shape_name) = @_;
    return $self->{'shape_param'}{$shape_name};
}

sub set_shape_params {
    my ($self, $shape_name, $params) = @_;
    
    $self->{'shape_param'}{$shape_name} = $params;
}

sub get_variable {
    my ($self, $name, $type) = @_;
    return $self->{$type}{$name};
}

sub set_variable {
    my ($self, $name, $type, $value) = @_;
    
    $self->{$type}{$name} = $value;
    
    if ($type eq 'group') {
        $name =~ s/\$//g;
        $value->rename($name);
    
        foreach my $layer ($value->get_layers()) {
            my $layername = $layer->get_name();
            $self->{'layer'}{"\$$name.$layername"} = $layer;
        }
    }
}

sub variable_exists {
    my ($self, $name, $expected_type) = @_;
    
    if ($expected_type eq 'layer') {
        my ($groupname) = $name =~ /^(\$\w+)/;
        my ($layername) = $name =~ /^\$\w+\.(\w+)/;
                
        if (exists($self->{'group'}{$groupname})) {
            return $self->{'group'}{$groupname}->layer_exists($layername);
        }
        
        return 0;
    }
    
    return exists($self->{$expected_type}{$name});
}

# returns a hash here because we call this from param parser, and we need to defer the error report
sub check_vartype {
    my ($self, $raw_name, $expected_type) = @_;
    
    my ($sigil) = $raw_name =~ /^([\$\%\@\*])/;
    my %prefix = ('$' => 'group', '@' => 'mask', '%' => 'weight', '*' => 'shape');
    unless (defined($sigil)) {
        return {
            'error' => 1,
            'error_msg' => "unknown variable type for '$raw_name'."
        };
        
        return -1;
    }
    
    my $actual = $prefix{$sigil};
    
    if ($raw_name =~ /\./) {
        if ($actual eq 'group') {
            $actual = 'layer';
        }
        else {
            return {
                'error' => 1,
                'error_msg' => "unknown variable type for '$raw_name'."
            };
        }
    }
    
    if ($sigil eq '$') {
        if (($expected_type eq 'layer') and ($raw_name !~ /\./)) {
            return {
                'error' => 1,
                'error_msg' => "parameter $raw_name is expected to be of type 'layer' but was actually parsed as type 'group'."
            };
        }
        elsif (($expected_type eq 'group') and ($raw_name =~ /\./)) {
            return {
                'error' => 1,
                'error_msg' => "variable $raw_name is expected to be of type 'group' but was actually parsed as type 'layer'."
            };
        }
    }
    elsif (($sigil eq '@') and ($expected_type ne 'mask')) {
        return {
            'error' => 1,
            'error_msg' => "variable $raw_name is expected to be of type 'mask' but was actually parsed as type '$actual'."
        };
    }
    elsif (($sigil eq '%') and ($expected_type ne 'weight')) {
        return {
            'error' => 1,
            'error_msg' => "variable $raw_name is expected to be of type 'weight' but was actually parsed as type '$actual'."
        };
    }
    elsif (($sigil eq '*') and ($expected_type ne 'shape')) {
        return {
            'error' => 1,
            'error_msg' => "variable $raw_name is expected to be of type 'shape' but was actually parsed as type '$actual'."
        };
    }
    
    return {
        'error' => 0,
        'name' => $raw_name
    }
}

# TODO: replace all error printing with this
sub report_error {
    my ($self, $msg) = @_;
    
    $msg =~ s/\n//g;
    
    $Text::Wrap::columns = 76;
    print "\n";
    print wrap("", "  ", "** ERROR occurred during command:");
    print "\n\n";
    print wrap("    ", "    ", $self->{'current_line'});
    print "\n\n";
    print wrap(" ", "  ", "* " . $msg);
    print "\n\n";
}

sub report_warning {
    my ($self, $msg) = @_;
    
    $msg =~ s/\n//g;
    
    $Text::Wrap::columns = 76;
    print "\n";
    print wrap("", "  ", "* WARNING for command:");
    print "\n\n";
    print wrap("    ", "    ", $self->{'current_line'});
    print "\n\n";
    print wrap(" ", "  ", "* " . $msg);
    print "\n\n";
}

sub report_message {
    my ($self, $msg, $extra_indent) = @_;
    
    $msg =~ s/\n//g;
    
    my $ei = 0;
    $ei = $extra_indent if defined $extra_indent;
    
    $Text::Wrap::columns = 76;
    $Text::Wrap::separator="\n  ";
    $msg =~ s/\r|\n/ /g;
    $msg =~ s/\s+/ /;
    $msg =~ s/^\s+//;
    $msg =~ s/\s+$//;
    
    print wrap("  " . (" " x $ei), "" . (" " x $ei) , $msg);
}

sub list {
    my ($self, @items) = @_;
    
    print "\n  ";
    print join ("\n  ", @items);
    print "\n\n";
    
    return 1;
}

1;