package Civ4MapCad;

use strict;
use warnings;

use Text::Wrap qw(wrap);
use Config::General;

use Civ4MapCad::Commands;
our $repl_table = create_dptable Civ4MapCad::Commands; 
delete $repl_table->{'register_shape'};

use Civ4MapCad::Util qw(deepcopy);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($spec) = @_;
    
    our %config = Config::General->new('def/config.cfg')->getall();
    $config{'max_players'} = 0;
    
    my $obj = {
        'config' => \%config,
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
        'buffer_ready' => 0,
        'ref_id' => 0, # these two are for killing circular references between group/layer when we use deepcopy, ugh
        'ref_table' => {}
    };
    
    return bless $obj, $class;
}

sub set_ref_id {
    my ($self, $obj) = @_;
    $self->{'ref_id'} ++;
    $obj->{'ref_id'} = $self->{'ref_id'};
    $self->{'ref_table'}{$self->{'ref_id'}} = $obj;
}

sub next_ref_id {
    my ($self) = @_;
    my $current = $self->{'ref_id'};
    return $self->{'ref_id'};
}

sub process_command {
    my ($self, $command) = @_;
    
    if ($self->is_off_script()) {
        open (my $log, '>>', 'output.txt') or die $!;
        print $log join('', @_[1..$#_]);
        my @has_nl = grep { $_ =~ /\n/ } @_[1..$#_];
        print $log "\n" unless @has_nl > 0;
        close $log;
    }
    
    my $ret = eval { $self->_process_command($command) };
    
    if ($@) {
        print "*** FATAL ERROR: ";
        print $@;
        print "\n";
        
        # if we get an error, that means we need to clear out the expected returns of all script calls
        $self->{'return_stack'} = [];
        return -1;
    }
    
    $self->ready_buffer_bar();
    $self->clear_printed();
    $self->collect_garbage();
    
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
    $command =~ s/\s+\=\>\s+/ => /g;
    
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
            print "  Returns a result from a script to be assigned to some other object. The \n";
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
            $self->report_warning("return used in script but no result from script was specified.");
            return 1;
        }
        
        my ($expected_name, $expected_type, $dump_output) = $self->shift_script_return();
        
        my $has_result = 1;
        if (($expected_name eq '') and ($expected_type eq '')) {
            $has_result = 0;
        }
        elsif ($expected_type ne $return_type) {
            $self->report_error("Result variable '$expected_name' does not match type of returned variable '$to_return'.");
            return -1;
        }
        
        if ($dump_output == 1) {
            if ($return_type eq 'group') {
                $self->process_command("debug_group $to_return");
            }
            elsif ($return_type eq 'layer') {
                $self->process_command("debug_layer $to_return");
            }
            elsif ($return_type eq 'mask') {
                $self->process_command("debug_mask $to_return");
            }
            elsif ($return_type eq 'weight') {
                $self->process_command("debug_weight $to_return");
            }
            else {
                $self->report_error("Can't debug result '$to_return'!");
                return -1;
            }
            
            $self->remove_log();
        }
        
        if ($has_result) {
            my $obj = $self->get_variable($to_return, $return_type);
            my $copy = deepcopy($obj);
            $self->set_variable($expected_name, $return_type, $copy);
        }
        
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
        
            $params[0] =~ s/\"//g;
            @com_list = grep { $_ =~ /$params[0]/ } @com_list;
        
            if (@com_list == 0) {
                print qq[\n* No commands found that match query '$params[0]'.\n\n];
                return 1;
            }
        }
        
        my $com = join ("\n    ", @com_list);
        print qq[\n  Available commands are:\n\n    $com\n\n];
        print qq[  You can filter this list with a phrase, e.g. "help mask" to show all\n  commands with "mask" in their name.\n\n] if @params == 0;
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
    my ($self, $script_path, $expects_return) = @_;
    
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
        
        $line =~ s/^\s*// if $current_line eq '';
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
    
    my $ret_count = 0;
    foreach my $l (@filtered_lines) {
        my ($i, $line) = @$l;
        $ret_count ++ if $line =~ /^\s*return/;
    }
    
    if ($ret_count > 1) {
        $self->report_error("multiple return statements used in '$script_path'.");
        return -1;
    }
    
    if (($expects_return == 1) and ($ret_count == 0)) {
        $self->report_error("A result is expected from '$script_path' but no return command was found in the script.");
        return -1;
    }
    
    foreach my $l (@filtered_lines) {
        my ($i, $line) = @$l;
        
        my $ret = $self->process_command($line);
        if ($ret == -1) {
            $self->buffer_bar();
            $self->report_message(" ** inducing early script exit for script '$script_path' due to error on line '$i'...");
            print "\n\n";
            $self->register_print();
            return -1;
        }
    }
    
    return 1;
}

sub push_script_return {
    my ($self, $name, $type, $dump) = @_;
    push @{ $self->{'return_stack'} }, [$name, $type, $dump];
}

sub return_stack_empty {
    my ($self) = @_;
    return 1 if @{ $self->{'return_stack'} } == 0;
    return 0;
}

sub shift_script_return {
    my ($self) = @_;
    my ($ret) = pop @{ $self->{'return_stack'} };
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
    
    $command =~ s/\s+/ /g;
    
    if ((@{$self->{'log'}} > 0) and ($self->{'log'}[-1] eq $command)) {
        return;
    }
    
    push @{ $self->{'log'} }, $command;
}

sub remove_log {
    my ($self, $command) = @_;
    pop @{ $self->{'log'} };
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
    
        my $layer_name = $layer->get_name();
        my $full_name = $layer->get_full_name();
    
        $layer->get_group()->delete_layer($layer_name);
        delete $self->{'layer'}{$full_name};
        
        $layer->destroy_layer();
        return;
    }
    elsif ($type eq 'group') {
        my $group = $self->get_variable($name, $type);
        delete $self->{$type}{$name};
        $group->destroy_group();
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
        $value->rename_group($name);
        
        # clear out old layer names, in case some got deleted in a merge
        foreach my $full_layer_name (keys %{ $self->{'layer'} }) {
            if ($full_layer_name =~ /^\$$name\./) {
                delete $self->{'layer'}{$full_layer_name};
            }
        }
        
        # now add them back
        foreach my $layer ($value->get_layers()) {
            my $layer_name = $layer->get_name();
            $self->{'layer'}{"\$$name.$layer_name"} = $layer;
            $layer->set_membership($value);
        }
    }
}

sub _assign_layer_result {
    my ($self, $result_name, $result_layer) = @_;
    
    my ($result_group_name, $result_layer_name) = $result_name =~ /\$(\w+)\.(\w+)/;
    my $group = $self->get_variable('$' . $result_group_name, 'group');
    $result_layer->rename_layer($result_layer_name);
    
    my $old_group = $result_layer->get_group();
    if ((!defined($old_group)) or ($old_group->get_name() ne $result_group_name)) {
        $result_layer->recenter();
    }
    
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
    
    if ($type->{'type'} ne $expected_type) {
        return {
            'error' => 1,
            'error_msg' => "parameter given at '$raw_name' was expected to be of type '$expected_type' but is actually parsed as type '$type->{'type'}'."
        };
    }
    
    my $actual = $type->{'type'};
    if ($sigil eq '$') {
        if (($expected_type eq 'layer') and ($raw_name !~ /\./)) {
            return {
                'error' => 1,
                'error_msg' => "parameter given as '$raw_name' is expected to be of type 'layer' but was actually parsed as type 'group'."
            };
        }
        elsif (($expected_type eq 'group') and ($raw_name =~ /\./)) {
            return {
                'error' => 1,
                'error_msg' => "parameter given as '$raw_name' is expected to be of type 'group' but was actually parsed as type 'layer'."
            };
        }
    }
    elsif (($sigil eq '@') and ($expected_type ne 'mask')) {
        return {
            'error' => 1,
            'error_msg' => "parameter given as '$raw_name' is expected to be of type 'mask' but was actually parsed as type '$actual'."
        };
    }
    elsif (($sigil eq '%') and ($expected_type ne 'weight')) {
        return {
            'error' => 1,
            'error_msg' => "parameter given as '$raw_name' is expected to be of type 'weight' but was actually parsed as type '$actual'."
        };
    }
    elsif (($sigil eq '*') and ($expected_type ne 'shape')) {
        return {
            'error' => 1,
            'error_msg' => "parameter given as '$raw_name' is expected to be of type 'shape' but was actually parsed as type '$actual'."
        };
    }
    elsif (($sigil eq '') and ($expected_type ne 'terrain')) {
        return {
            'error' => 1,
            'error_msg' => "parameter given as '$raw_name' is expected to be of type 'terrain' but was actually parsed as type '$actual'."
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
    $Text::Wrap::unexpand = 0;
    
    print "\n";
    print wrap("", "  ", "** ERROR occurred during command:");
    print "\n\n";
    print wrap("    ", "    ", $self->{'current_line'});
    print "\n\n";
    print wrap(" ", "   ", "* " . $msg);
    print "\n\n";
    
    $self->register_print();
    
    # if we get an error, that means we need to clear out the expected returns of all script calls
    $self->{'return_stack'} = [];
}

sub report_warning {
    my ($self, $msg, $dont_print_line) = @_;
    $self->buffer_bar();
    
    $msg =~ s/\n//g;
    $Text::Wrap::columns = 76;
    $Text::Wrap::unexpand = 0;
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
    $Text::Wrap::unexpand = 0;
    
    my @parts = split "<BREAK>", $msg;
    
    foreach my $i (0..$#parts) {
        my $part = $parts[$i];
        $part =~ s/\r|\n/ /g;
        $part =~ s/\s+/ /g;
        $part =~ s/^\s+//;
        $part =~ s/\s+$//;
        print wrap("  " . (" " x $ei), "" . (" " x $ei) , $part);
        print "\n\n" if $i < $#parts;
    }
}

sub list {
    my ($self, @items) = @_;
    $self->buffer_bar();
    
    print "\n  ";
    print join ("\n  ", @items);
    print "\n\n";
    
    $self->register_print();
}

# shitty do-it-yourself garbage collection to get rid of circular references between layer/group
# whenever layer/group is created, including via deepcopy, we assign it a unique reference id
# if, at the end of executing a command, that object is not found within $state->{'layer'} or 
# $state->{'group'} then we nuke it with extreme prejudice to prevent gradually leaking memory
#
# these shenanigans are necessary because we deepcopy all over the damn place
sub collect_garbage {
    my ($self) = @_;
    
    my %still_active;
    foreach my $layer (values %{ $self->{'layer'} }) {
        $still_active{ $layer->{'ref_id'} } = 1;
    }
    foreach my $layer (values %{ $self->{'group'} }) {
        $still_active{ $layer->{'ref_id'} } = 1;
    }
    
    foreach my $id (keys %{ $self->{'ref_table'} }) {
        if (! exists $still_active{$id}) {
            
            if (ref($self->{'ref_table'}{$id}) =~ /Layer/i) {
                $self->{'ref_table'}{$id}->destroy_layer();
            }
        }
    }
}

sub debug_ref_table {
    my ($self, $still_active) = @_;

    print "    ------------------------------------------    \n";
    foreach my $id (keys %{ $self->{'ref_table'} }) {
        my $type = 'group';
        $type = 'layer' if ref($self->{'ref_table'}{$id}) =~ /Layer/i;
        my $status = (exists $still_active->{$id}) ? 'active' : 'inactive';
        my $name = $self->{'ref_table'}{$id}->{'name'};
        $name = 'undef' unless defined($name);
        
        if ($type eq 'layer') {
            if (defined $self->{'ref_table'}{$id}{'member_of'}) {
                $name = $self->{'ref_table'}{$id}->get_full_name();
            }
            else {
                $name = '$undef.' . $name;
            }
        }
        else {
            $name = '$' . $name;
            my @layers = $self->{'ref_table'}{$id}->get_layers();
            $name .= ('/' . (@layers+0));
        }

        my $padding = ' ' x (20 - length($name));
        $padding = ' ' if (20 - length($name)) < 1;
        
        printf "    | %03d %s: %7s %s$padding|\n", $id, $type, $status, $name;
    }
    print "    ------------------------------------------    \n\n";
    
}

1;