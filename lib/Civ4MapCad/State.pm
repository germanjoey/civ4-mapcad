package Civ4MapCad::State;

use strict;
use warnings;

use Text::Wrap qw(wrap);

use Civ4MapCad::Commands;
our $repl_table = create_dptable Civ4MapCad::Commands; 
delete $repl_table->{'register_shape'};

use Civ4MapCad::Util qw(deepcopy);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($spec) = @_;
    
    my $obj = {
        'data' => {},
        'output_dir' => './',
        'variables' => {},
        'group' => {},
        'shape' => {},
        'shape_param' => {},
        'mask' => {},
        'terrain' => {},
        'in_script' => 0,
        'log' => [],
        'return_stack' => [],
        'already_printed' => 0,
        'buffer_ready' => 0
    };
    
    return bless $obj, $class;
}

sub process_command {
    my ($self, $command) = @_;
    
    my $ret = eval { $self->_process_command($command) };
    
    if ($@) {
        print "*** FATAL ERROR: ";
        print $@;
        print "\n";
        return -1;
    }
    
    $self->ready_buffer_bar();
    $self->clear_printed();
          
    return $ret;
}

sub _process_command {
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
    
    if ($self->is_off_script()) {
        $self->add_log($command);
    }
    
    if ($command_name eq 'return') {
        if ((@params == 1) and ($params[0] eq '--help')) {
            $self->buffer_bar();
        
            print "\n";
            print "  Command format:\n\n";
            print "  return <result>\n\n";
            print "  Description:\n";
            print "  Returns a result from a script to be assigned to some other objec. The \n";
            print "  return type may be any type of group/layer/mask/weight, but not shape. If\n";
            print "  this result is ignored, a warning will be produced.\n\n";
            
            $self->register_print();
            return 1;
        }
        
        if ($self->is_off_script()) {
            return 1;
        }
        
        if ((@params != 1)) {
            $self->report_error("Incorrect command format.");
            
            print "  Command format:\n\n";
            print "  return <result>\n\n";
            return -1;
        }
        
        my $to_return = $params[0];
        my $return_type = $self->get_variable_type_from_name($to_return);
        if (exists $return_type->{'error'}) {
            $self->report_error($return_type->{'error_msg'});
            return -1;
        }
        $return_type = $return_type->{'type'};
        
        if ($return_type eq 'shape') {
            $self->report_error("Shapes cannot be returned from scripts.");
            return -1;
        }
        
        if (!$self->variable_exists($to_return, $return_type)) {
            $self->report_error("Unknown variable '$to_return' of type '$return_type'.");
            return -1;
        }
        
        if ($self->return_stack_empty()) {
            $self->report_warning("return used but no result from script was specified.");
            return 1;
        }
        
        my ($expected_name, $expected_type) = $self->shift_script_return();
        if ($expected_type ne $return_type) {
            $self->report_error("Result variable '$expected_name' does not match returned variable '$to_return'.");
        }
        
        my $obj = $self->get_variable($to_return, $return_type);
        my $copy = deepcopy($obj);
        
        $self->set_variable($expected_name, $return_type, $copy);
        
        return 1;
    }
    
    elsif ($command_name eq 'eval') {
        $self->buffer_bar();
        
        if ((@params == 1) and ($params[0] eq '--help')) {
            print "\n";
            print "  Command format:\n\n";
            print "  eval <code>\n\n";
            print "  Description:\n";
            print "  Evaluates perl code and prints the result. Everything on the command line\n";
            print "  after the 'eval' keyword will be evaluated.\n\n";
            return 1;
        }
    
        my $full_line = join ' ', @params;
        print eval $full_line;
        print "\n";
        
        return 1;
    }
    
    elsif ($command_name eq 'exit') {
        if ((@params == 1) and ($params[0] eq '--help')) {
            $self->buffer_bar();
            print "\n";
            print "  Command format:\n\n";
            print "  exit\n\n";
            print "  Description:\n";
            print "  Exits.\n\n";
            $self->register_print();
            return 1;
        }
            
        $self->process_command('write_log');
        exit(0);
    }
    
    elsif ($command_name eq 'help') {
        $self->buffer_bar();
        
        my @com_list = keys %$repl_table;
        push @com_list, ('eval', 'exit', 'help', 'return');
        @com_list = sort @com_list;
        
        if (@params == 1) {
            if ($params[0] eq '--help') {
                $self->buffer_bar();
                print "\n";
                print "  Command format:\n\n";
                print "  help searchstring\n\n";
                print "  Description:\n";
                print "  Prints the list of available commands. A search string is optional, but,\n";
                print "  if present, the list of available commands will be filtered.\n";
                
                $self->register_print();
                return 1;
            }
        
            @com_list = grep { $_ =~ /$params[0]/ } @com_list;
        
            if (@com_list == 0) {
                print qq[\n* No commands found that match query '$params[0]'.\n\n];
            }
        }
        
        my $com = join ("\n    ", @com_list);
        print qq[\n  Available commands are:\n\n    $com\n\n];
        print qq[  You can filter this list with a phrase, e.g. "help weight" to show all\n  commands with "weight" in their name.\n\n] if @params == 0;
        print qq[  For more info about a specific command, type its name plus --help,\n  e.g. "evaluate_weight --help"\n\n];
        
        return 1;
    }
    
    elsif (exists $repl_table->{$command_name}) {
        my $ret = $repl_table->{$command_name}->($self, @params);
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
        return -1;
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
            $self->report_message(" ** inducing early script exit for script '$script_path' due to error on line '$i'...");
            print "\n\n";
            return -1;
        }
    }
    
    return 1;
}

sub push_script_return {
    my ($self, $name, $type) = @_;
    push @{ $self->{'return_stack'} }, [$name, $type];
}

sub return_stack_empty {
    my ($self) = @_;
    return 1 if @{ $self->{'return_stack'} } == 0;
    return 0;
}

sub shift_script_return {
    my ($self) = @_;
    my ($ret) = shift @{ $self->{'return_stack'} };    
    return @$ret;
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
    
    if ((@{$self->{'log'}} > 0) and ($self->{'log'}[-1] eq $command)) {
        return;
    }
    
    push @{ $self->{'log'} }, $command;
}

sub get_log {
    my ($self) = @_;
    return @{ $self->{'log'} };
}

sub clear_log {
    my ($self) = @_;
    $self->{'log'} = [];
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

# name is a "full" name, with sigil, plus group for layers
sub delete_variable {
    my ($self, $name, $type) = @_;
    
    if ($type eq 'layer') {
        my $layer = $self->get_variable($name, $type);
    
        my $name = $layer->get_name();
        my $full_name = $layer->get_full_name();
    
        $layer->get_group()->delete_layer($name);
        delete $self->{'layer'}{$full_name};
        return;
    }
    else {
        delete $self->{$type}{$name};
    }
}

# name is a "full" name, with sigil, plus group for layers
sub get_variable {
    my ($self, $name, $type) = @_;
    return $self->{$type}{$name};
}

# name is a "full" name, with sigil, plus group for layers
sub set_variable {
    my ($self, $name, $type, $value) = @_;
    
    if ($type eq 'layer') {
        $self->_assign_layer_result($name, $value);
        return;
    }
    
    $self->{$type}{$name} = $value;
    
    if ($type eq 'group') {
        $name =~ s/\$//g;
        $value->rename($name);
        
        # clear out old layer names, in case some got deleted in a merge
        foreach my $full_layer_name (keys %{ $self->{'layer'} }) {
            if ($full_layer_name =~ /^\$$name/) {
                delete $self->{'layer'}{$full_layer_name};
            }
        }
    
        # now add them back
        foreach my $layer ($value->get_layers()) {
            my $layer_name = $layer->get_name();
            $self->{'layer'}{"\$$name.$layer_name"} = $layer;
        }
    }
}

sub _assign_layer_result {
    my ($self, $result_name, $result_layer) = @_;
    
    my ($result_group_name, $result_layer_name) = $result_name =~ /\$(\w+)\.(\w+)/;
    my $group = $self->get_variable('$' . $result_group_name, 'group');
    $result_layer->rename($result_layer_name);
        
    if ($group->layer_exists($result_layer_name)) {
        $group->set_layer($result_layer_name, $result_layer);
    }
    else {
        my $result = $group->add_layer($result_layer);
        if (exists $result->{'error'}) {
            $self->report_warning($result->{'error_msg'});
        }
    }
    
    $result_layer->set_membership($group);
    
    $self->{'layer'}{'$' . "$result_group_name.$result_layer_name"} = $result_layer;
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
    
    return (exists($self->{$expected_type}{$name}) ? 1 : 0);
}

sub get_variable_type_from_name {
    my ($self, $raw_name) = @_;
    
    my ($sigil) = $raw_name =~ /^([\$\%\@\*])/;
    my %prefix = ('$' => 'group', '@' => 'mask', '%' => 'weight', '*' => 'shape');
    unless (defined($sigil)) {
        if ($raw_name =~ /^\w/) {
            return {'type' => 'terrain'};
        }
    
        return {
            'error' => 1,
            'error_msg' => "unknown variable type for '$raw_name'."
        };
        
        return -1;
    }
    
    if (($sigil eq '$') and ($raw_name =~ /\./)) {
        return {'type' => 'layer'};
    }
    else {
        return {'type' => $prefix{$sigil}};
    }
}

# returns a hash here because we call this from param parser, and we need to defer the error report
sub check_vartype {
    my ($self, $raw_name, $expected_type) = @_;
    
    my ($sigil) = $raw_name =~ /^([\$\%\@\*])/;
    
    my ($type) = $self->get_variable_type_from_name($raw_name);
    if (exists $type->{'error'}) {
        return $type;
    }
    
    my $actual = $type->{'type'};
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
    elsif (($sigil eq '') and ($expected_type ne 'terrain')) {
        return {
            'error' => 1,
            'error_msg' => "variable $raw_name is expected to be of type 'terrain' but was actually parsed as type '$actual'."
        };
    }
    
    return {
        'error' => 0,
        'name' => $raw_name
    }
}

sub ready_buffer_bar {
    my ($self) = @_;
    if ($self->is_off_script()) {
        $self->{'buffer_ready'} = 0;
    }
    else { 
        $self->{'buffer_ready'} = 1;
    }
}

sub buffer_bar {
    my ($self) = @_;
    
    if ($self->{'already_printed'} and $self->{'buffer_ready'}) {
        $self->{'buffer_ready'} = 0;
        print "-------------------------\n";
    }
}

sub clear_printed {
    my ($self) = @_;
    $self->{'already_printed'} = 0 if $self->is_off_script();
}

sub register_print {
    my ($self) = @_;
    
    if (!$self->is_off_script()) {
        $self->{'already_printed'} = 1;
    }
}

# TODO: replace all error printing with this
sub report_error {
    my ($self, $msg) = @_;
    $self->buffer_bar();
    
    $msg =~ s/\n//g;
    
    $Text::Wrap::columns = 76;
    print "\n";
    print wrap("", "  ", "** ERROR occurred during command:");
    print "\n\n";
    print wrap("    ", "    ", $self->{'current_line'});
    print "\n\n";
    print wrap(" ", "   ", "* " . $msg);
    print "\n\n";
    
    $self->register_print();
}

sub report_warning {
    my ($self, $msg, $dont_print_line) = @_;
    $self->buffer_bar();
    
    $msg =~ s/\n//g;
    
    $Text::Wrap::columns = 76;
    print "\n";
        
    if ($dont_print_line) {
        print wrap("", "  ", "* WARNING:");
        print "\n\n";
        print wrap(" ", "  ", "* " . $msg);
    }
    else {
        print wrap("", "  ", "* WARNING for command:");
        print "\n\n";
        print wrap("    ", "    ", $self->{'current_line'});
        print "\n\n";
        print wrap(" ", "  ", "* " . $msg);
    }
    
    print "\n\n";
    $self->register_print();
}

sub report_message {
    my ($self, $msg, $extra_indent) = @_;
    
    $msg =~ s/\n//g;
    my $ei = 0;
    $ei = $extra_indent if defined $extra_indent;
    
    $Text::Wrap::columns = 76;
    $Text::Wrap::separator="\n  ";
    $msg =~ s/\r|\n/ /g;
    $msg =~ s/\s+/ /g;
    $msg =~ s/^\s+//;
    $msg =~ s/\s+$//;
    
    print wrap("  " . (" " x $ei), "" . (" " x $ei) , $msg);
    
    $self->register_print();
}

sub list {
    my ($self, @items) = @_;
    $self->buffer_bar();
    
    print "\n  ";
    print join ("\n  ", @items);
    print "\n\n";
    
    $self->register_print();
}

1;