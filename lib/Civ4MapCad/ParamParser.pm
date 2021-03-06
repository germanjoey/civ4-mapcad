package Civ4MapCad::ParamParser;

use strict;
use warnings;

use List::Util qw(min max);
use Getopt::Long qw(GetOptionsFromArray :config pass_through);
use Civ4MapCad::Util qw(wrap_text);

# processes parameters to a command into something the commands can actually work with
# $raw_params is basically whatever came in on the command line after the command name
# $param_spec is a hash supplied by the command with this format:
#    'has_result' => 1,
#    'required' => ['type1', 'type2', etc],
#    'optional' => {
#        '-flag1' => 0,
#        'flag2' => 1
#    }
#
#  - required params are those that must be specified for the command. e.g. the mask_intersection commands requires
#    two different masks to do an intersection between them. for the param_spec, you need to specify a list of types
#
#  - has_result specifies whether the command expects a result. if it does, then it will assume that whatever was
#    the first argument specified will be overwritten with the result of the commmand, unless the command has a "=> $other_output"
#    at the end of it. e.g.:
#      "mask_intersection $mask1 $mask2" overwrites $mask1 with the intersection of mask1 and mask2
#      "mask_intersection $mask1 $mask2 => $mask3" sets $mask3 to the intersection of mask1 and mask2
#    if the command has no required params but has a result anyways, (e.g. new_group) has_result's value should be a type
#
#  - optional params are flags to set different variations for the command. e.g, --mode 3
#    each key in this hash is the name of an optional param, and its value is the default value if the param is not specified
#    - if the param name is prefixed with a -, it is assumed that this is a flag. e.g. --verbose --quiet --debug
#      the default values here specify true or false
#    - if the param name is not prefixed with a -, then it is assumed that this parameter will have some sort of value
#
# the output of parse is a hash containing a value for each input to the command. a special value, _result, specifies where the output of the command should go, if there is one.
# if an error occurred in parsing params, the error field of the result hash will be set, and the command should bail immediately.

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($state, $raw_params, $param_spec) = @_;
    
    my $calling_command = _find_calling_command($param_spec);
    $param_spec->{'command'} = $calling_command;
    my @calling_format = _report_calling_format($state, $param_spec);
    
    if ((@$raw_params == 1) and ($raw_params->[0] eq '--help')) {
        $state->buffer_bar();
        print "\n";
        print "  Command format:\n\n";
        $state->report_message($calling_format[0]);
        foreach my $i (1..$#calling_format) {
            print "\n  $calling_format[$i]";
        }
        
        print "\n\n";
        
        if (exists $param_spec->{'help_text'}) {
            print "  Description:\n";
            $state->report_message($param_spec->{'help_text'});
            print "\n\n";
        }
        
        $state->register_print();
        
        return bless {'error' => 0, 'done' => 1}, $class;
    }
    
    my $processed = _process($state, $raw_params, $param_spec);
    
    $processed->{'done'} = 0;
    
    my $has_help = 0;
    foreach my $param (@$raw_params) {
        $has_help = 1 if $param eq '--help';
    }
    
    if ($processed->{'error'} and $has_help) {
        $state->buffer_bar();
        
        print "\n";
        print "  Command format:\n\n";
        $state->report_message($calling_format[0]);
        foreach my $i (1..$#calling_format) {
            print "\n  $calling_format[$i]";
        }
        
        print "\n\n";
        
        if (exists $param_spec->{'help_text'}) {
            print "  Description:\n" ;
            $state->report_message($param_spec->{'help_text'});
            print "\n\n";
        }
        
        $state->register_print();
        
        $processed->{'done'} = 1;
        $processed->{'error'} = 0;
        
        return bless $processed, $class;
    }
    
    if ($processed->{'error'}) {
        $state->report_error($processed->{'error_msg'});
    }
    
    if ($processed->{'help'} or $processed->{'help_anyways'}) {
        $state->buffer_bar();
        
        print "\n" unless $processed->{'error'};
        print "  Command format:\n\n";
        $state->report_message($calling_format[0]);
        foreach my $i (1..$#calling_format) {
            print "\n  $calling_format[$i]";
        }
        
        if ((exists $param_spec->{'help_text'}) and ($processed->{'help'})) {
            print "  Description:\n";
            $state->report_message($param_spec->{'help_text'});
        }
        
        print "\n\n";
        
        $state->register_print();
    }
    
    return bless $processed, $class;
}

sub done {
    my ($self) = @_;
    return 1 if $self->{'done'};
    return 0;
}

sub has_error {
    my ($self) = @_;
    return 1 if $self->{'error'};
    return 0;
}

sub get_shape_params {
    my ($self) = @_;
    return $self->{'_shape_params'};
}

sub get_result_name {
    my ($self) = @_;
    return $self->{'_result'};
}

sub get_required {
    my ($self) = @_;
    return @{ $self->{'_required'} };
}

sub get_required_names {
    my ($self) = @_;
    return @{ $self->{'_required_names'} };
}

sub get_named {
    my ($self, $name) = @_;
    return $self->{$name};
}

# this is the function that produces the calling format of each command for the help tetx
sub _report_calling_format {
    my ($state, $param_spec) = @_;
    
    my $command_name = $param_spec->{'command'};
    my %prefix = ('group' => '$', 'mask' => '@', 'weight' => '%', 'shape' => '*', 'terrain' => '');
    
    my @required_list;
    foreach my $type (@{ $param_spec->{'required'} }) {
        if ($type eq 'layer') {
            push @required_list, "\$groupname.layername";
        }
        else {
            if (exists $prefix{$type}) {
                push @required_list, $prefix{$type} . $type . "name";
            }
            elsif ($type =~ /str/) {
                push @required_list, qq["string"];
            }
            else {
                push @required_list, $type;
            }
        }
    }
    
    my @optional_desc;
    my $optional = $param_spec->{'optional'};
    foreach my $opt (sort keys %$optional) {
        next if $opt eq 'help';
    
        if ($optional->{$opt} =~ /^(?:true|false)$/) {
            push @optional_desc, wrap_text("--$opt: optional; defaults to false.  " . $param_spec->{'optional_descriptions'}{$opt}, 4, 2) . "\n";
        }
        elsif ($optional->{$opt} =~ /\-?\d+\.\d+/) {
            push @optional_desc, wrap_text("--$opt float: defaults to $optional->{$opt}.  " . $param_spec->{'optional_descriptions'}{$opt}, 4, 2) . "\n";
        }
        elsif ($optional->{$opt} =~ /\-?\d+/) {
            push @optional_desc, wrap_text("--$opt int: defaults to $optional->{$opt}.  " . $param_spec->{'optional_descriptions'}{$opt}, 4, 2) . "\n";
        }
        else {
            push @optional_desc, wrap_text(qq[--$opt "string": defaults to "$optional->{$opt}".  ] . $param_spec->{'optional_descriptions'}{$opt}, 4, 2) . "\n";
        }
    }
    
    my $result = '';
    if (exists $param_spec->{'has_result'}) {
        if ($param_spec->{'has_result'} eq 'layer') {
            $result = " => \$other_groupname.other_layername";
        }
        else {
            $result = " => $prefix{$param_spec->{'has_result'}}other_$param_spec->{'has_result'}name";
        }
    }
    
    my $shape = '';
    $shape = " --shape_param1 value1 --shape_param2 value2" if exists $param_spec->{'has_shape_params'};
    
    my $optional_str = '';
    $optional_str = " [ --options ]" if @optional_desc > 0;
    
    my @format = ("$command_name @required_list$optional_str$shape$result\n");
    
    if ((@required_list > 0) and exists($param_spec->{'required_descriptions'})) {
        foreach my $i (1 .. @{ $param_spec->{'required_descriptions'} }) {
            my $desc = $param_spec->{'required_descriptions'}[$i-1];
            my $p = ($param_spec->{'required'}[$i-1] =~ /^\*/) ? '+' : '';
            push @format, "  param $i$p: $desc";
            
            if ($p eq '+') {
                push @format, "  NOTE: this last parameter is expected to be a list of many.";
            }
        }
    }
    
    if ($param_spec->{'allow_implied_result'}) {
        push @format, "\n  Specifying a result for this command is optional;";
        push @format, "if not specified, the original $param_spec->{'has_result'} will be overwritten.";
    }
    
    if (@optional_desc > 0) {
        my $num = @optional_desc + 0;
        push @format, "\n  Flag parameters (i.e. --thesethings) specify some special/alternate";
        push @format, "behaivor of the command and are always optional.";
        push @format, "This command has $num possible optional parameters:\n";
        push @format, @optional_desc;
        $format[-1] =~ s/\n$//;
    }
    
    return @format;
}

# process the damn params
sub _process {
    my ($state, $raw_params, $param_spec) = @_;
    
    my $calling_command = $param_spec->{'command'};
    my $optional = $param_spec->{'optional'} || {};
    my $required = $param_spec->{'required'} || [];
    my $required_descriptions = $param_spec->{'required_descriptions'} || [];
    my $has_shape_params = $param_spec->{'has_shape_params'};
    my $help_text = $param_spec->{'help_text'} || '';
    
    my $has_result = $param_spec->{'has_result'};
    my $allow_implied_result = $param_spec->{'allow_implied_result'};
    $optional->{'help'} = 'false';
    my %processed_params = ('error' => 0);
    
    if (exists($param_spec->{'allow_implied_result'}) and (! exists($param_spec->{'has_result'}))) {
        die "*** command definition error: command has 'allow_implied_result' specified but not 'has_result'!";
    }
    
    # figure out result
    my $implied_result = 0;
    if ((@$raw_params >= 2) and ($raw_params->[-2] eq '=>')) {
        if (! $has_result) {
            $processed_params{'error_msg'} = "a result is specified, but this command does not produce one.";
            $processed_params{'error'} = 1;
            $processed_params{'help_anyways'} = 1;
            return \%processed_params;
        }
        
        my $result_name = pop @$raw_params;
        my $operator = pop @$raw_params;
        
        $processed_params{'_result'} = $result_name;
    }
    elsif (defined($has_result) and $allow_implied_result) {
        $implied_result = 1;
    }
    
    # massage params to allow single or double dash
    my @preproc;
    
    my $current_string = '';
    my $open_string = 0;
    
    # recombine strings back to their original form
    foreach my $raw (@$raw_params) {
        if (($open_string == 1) or ($raw =~ /^(?:,)?\"/)) {
            $open_string = 1;
            
            $current_string .= $raw;
            
            if ($raw =~ /\"(?:,)?$/) {
                push @preproc, $current_string;
                
                $open_string = 0;
                $current_string = '';
            }
            else {
                $current_string .= ' ';
            }
            
            next;
        }
    
        $raw =~ s/^\-+/-/;
        $raw =~ s/^-(?!\d)/--/;
        
        if ($raw eq '=>') {
            $processed_params{'error_msg'} = "a result operator was specified in a way that does not make sense.";
            $processed_params{'error'} = 1;
            $processed_params{'help_anyways'} = 1;
            return \%processed_params;
        }
        
        push @preproc, $raw;
    }
    
    foreach my $p (@preproc) {
        $p =~ s/^,+//;
        $p =~ s/,+$//;
    }
    
    if ($open_string) {
        $processed_params{'error_msg'} = "parse error, string was found to have an open quote.";
        $processed_params{'error'} = 1;
        $processed_params{'help_anyways'} = 1;
        return \%processed_params;
    }
    
    # get optional flags
    my $optional_list = _make_opt_list ($optional, \%processed_params);
    GetOptionsFromArray(\@preproc, \%processed_params, @$optional_list);
    
    # strip " from optional strings
    foreach my $opt (keys %$optional) {
        if (exists $processed_params{$opt}) {
            # only strip from strings
            if (($optional->{$opt} !~ /^(?:true|false)$/) and ($optional->{$opt} !~ /\-?\d+\.\d+/) and ($optional->{$opt} !~ /\-?\d+/)) {
                $processed_params{$opt} =~ s/"//g;
                $processed_params{$opt} =~ s/\s+$//g;
            }
        }
    }
    
    # fix up the named parameters
    if ((!$has_shape_params) and (@preproc != @$required) and (@$required > 0) and ($required->[-1] !~ /^\*/)) {
        my @unknown;
        foreach my $item (@preproc) {
            if ($item =~ /^\-\-/) {
                $item =~ s/^\-\-//;
                push @unknown, $item;
            }
        }
        
        if (@unknown > 0) {
            $processed_params{'error_msg'} = "the following named parameters are either unknown or recieved values that did not match their type: @unknown.";
        }
        else {
            $processed_params{'error_msg'} = "this command was supplied an incorrect number of required parameters.";
        }
        
        $processed_params{'error'} = 1;
        $processed_params{'help_anyways'} = 1;
        return \%processed_params;
    }
    
    $processed_params{'_required'} = [] if @preproc > 0;
    $processed_params{'_required_names'} = [] if @preproc > 0;
    
    my $i=0;
    my @shape_param_list;
    
    # remnants of @preproc are the required params; resolve those to what the command expects or else throw
    # an error back if there's a mismatch
    while (1) {
        last if $i > $#preproc;
    
        if ($preproc[$i] =~ /^\-\-/) {
            push @shape_param_list, $preproc[$i];
            push @shape_param_list, $preproc[$i+1];
            $i += 2;
            next;
        }
    
        my $expected_type = ((@$required > 0) and ($required->[-1] =~ /^\*/)) ? $required->[min($i, $#$required)] : ((@$required > 0) ? $required->[$i] : undef);
        
        if (! defined($expected_type)) {
            $processed_params{'error_msg'} = "Do not know what to do with unexpected parameter '$preproc[$i]'. (perhaps you intended to assign this to a result?)";
            $processed_params{'error'} = 1;
            $processed_params{'help_anyways'} = 1;
            return \%processed_params;
        }
        
        if ($expected_type =~ /int/) {
            unless ($preproc[$i] =~ /^[-+]?\d+$/) {
            
                $processed_params{'error_msg'} = "parameter '$preproc[$i]' was expected to be an integer value but yet is not.";
                $processed_params{'error'} = 1;
                $processed_params{'help_anyways'} = 1;
                return \%processed_params;
            };
            
            push @{ $processed_params{'_required_names'} }, '';
            push @{ $processed_params{'_required'} }, $preproc[$i];
            $i++;
            next;
        }
        elsif ($expected_type =~ /float/) {
            unless ($preproc[$i] =~ /^[-+]?\d+(?:\.\d+(?:[eE][-+]?\d+)?)?$/) {
                $processed_params{'error_msg'} = "parameter '$preproc[$i]' was expected to be a floating point value but yet is not.";
                $processed_params{'error'} = 1;
                $processed_params{'help_anyways'} = 1;
                return \%processed_params;
            };
        
            push @{ $processed_params{'_required_names'} }, '';
            push @{ $processed_params{'_required'} }, $preproc[$i];
            $i++;
            next;
        }
        
        elsif ($expected_type =~ /str/) {
            if (($preproc[$i] !~ /^"/) or ($preproc[$i] !~ /"$/)) {
                $processed_params{'error_msg'} = "a string was expected for '$preproc[0]'; all strings must be enclosed in double-quotes.";
                $processed_params{'error'} = 1;
                $processed_params{'help_anyways'} = 1;
                return \%processed_params;
            }
        
            $preproc[$i] =~ s/^"//;
            $preproc[$i] =~ s/"$//;
            $preproc[$i] =~ s/\s+$//g;
            push @{ $processed_params{'_required_names'} }, '';
            push @{ $processed_params{'_required'} }, $preproc[$i];
            $i++;
            next;
        }
        
        elsif ($expected_type =~ /terrain/) {
            if (! $state->variable_exists($preproc[$i], 'terrain')) {
                $processed_params{'error'} = 1;
                $processed_params{'error_msg'} = "a variable of type terrain named '$preproc[$i]' does not exist.";
                return \%processed_params;
            }
        
            push @{ $processed_params{'_required_names'} }, $preproc[$i];
            push @{ $processed_params{'_required'} }, $state->get_variable($preproc[$i], 'terrain');
            $i++;
            next;
        }
        
        my $check_result = $state->check_vartype($preproc[$i], $expected_type);
        if ($check_result->{'error'} == 1) {
            $processed_params{'error_msg'} = $check_result->{'error_msg'};
            $processed_params{'error'} = 1;
            return \%processed_params;
        };
        my $name = $check_result->{'name'};
    
        # now check for typos or whatever
        if (! $state->variable_exists($name, $expected_type)) {
            $processed_params{'error'} = 1;
            
            if ($expected_type eq 'layer') {
                my ($groupname) = $name =~ /^(\$\w+)/;
                my ($layername) = $name =~ /^\$\w+\.(\w+)/;
                
                if (! $state->variable_exists($groupname, 'group')) {
                    $processed_params{'error_msg'} = "a variable of type group named '$groupname' does not exist.";
                    return \%processed_params;
                }
                else {
                    $processed_params{'error_msg'} = "group '$groupname' does not contain a layer named '$layername'.";
                    return \%processed_params;
                }
            }
            else {
                $processed_params{'error_msg'} = "a variable of type '$expected_type' named '$name' does not exist.";
                return \%processed_params;
            }
        }
        
        push @{ $processed_params{'_required_names'} }, $name;
        push @{ $processed_params{'_required'} }, $state->get_variable($name, $expected_type);
        
        $i ++;
    }
    
    # finally, if we have an implied_result, set that to be the command's destination
    if ($has_result && $implied_result) {
        my $check_result = $state->check_vartype($preproc[0], $required->[0]);
        if ($check_result->{'error'} == 1) {
            $processed_params{'error_msg'} = $check_result->{'error_msg'};
            $processed_params{'error'} = 1;
            return \%processed_params;
        };
        my $result_name = $check_result->{'name'};
        
        $processed_params{'_result'} = $result_name;
        $processed_params{'_result_type'} = $required->[0];
    }
    
    # otherwise, we set it to the new destination
    elsif ($has_result and exists($processed_params{'_result'})) {
        my $check_result = $state->check_vartype($processed_params{'_result'}, $has_result);
        
        if ($check_result->{'error'} == 1) {
            $processed_params{'error_msg'} = $check_result->{'error_msg'};
            $processed_params{'error'} = 1;
            return \%processed_params;
        };
        
        my $result_name = $check_result->{'name'};
        
        # if we have a layer result, we have to make sure the group exists first!
        # however, the layer itself doesn't need to exist, since we'll be generating it
        if ($result_name =~ /^\$(\w+)\.(\w+)/) {
            my ($group_name) = $result_name =~ /^(\$\w+)/;
            if (! $state->variable_exists($group_name, 'group')) {
                $processed_params{'error_msg'} = "a variable of type group named '$group_name' used in the result does not exist.";
                $processed_params{'error'} = 1;
                return \%processed_params;
            }
        }
        
        $processed_params{'_result'} = $result_name;
        $processed_params{'_result_type'} = $has_result;
    }
    
    # a result was expected but none was supplied!
    elsif ($has_result) {
        $processed_params{'error_msg'} = "a result is produced from this command but no target variable was given.";
        $processed_params{'error'} = 1;
        $processed_params{'help_anyways'} = 1;
        return \%processed_params;
    }
    
    # this should only be called for new_mask_from_shape, which has a shape as its first (and only) required argument
    if ($has_shape_params) {
        my $shape_name = $preproc[0];
    
        my %shape_args;
        my $shape_param_spec = $state->get_shape_params($preproc[0]);
        my $shape_opts = _make_opt_list($shape_param_spec, \%shape_args);
        
        GetOptionsFromArray(\@shape_param_list, \%shape_args, @$shape_opts);
        $processed_params{'_shape_params'} = \%shape_args;
    }
        
    if ((@$required > 0) and ((! exists $processed_params{'_required'}) or (@{ $processed_params{'_required'} } < @$required))) {
        $processed_params{'error_msg'} = "The number of given parameters does not match the number expected.";
        $processed_params{'error'} = 1;
        $processed_params{'help_anyways'} = 1;
    }
    
    $processed_params{'_spec'} = {
        'command' => $calling_command,
        'optional' => $optional,
        'required' => $required,
        'required_descriptions' => $required_descriptions,
        'has_shape_params' => $has_shape_params,
        'has_result' => $has_result,
        'help_text' => $help_text,
        'allow_implied_result' => $allow_implied_result
    };
    
    return \%processed_params;
}

# CAN ONLY BE CALLED FROM new() !!!!
sub _find_calling_command {
    my ($param_spec) = @_;
    
    my $far_back = 2;
    my $root;
    
    while (1) {
        my ($package, $filename, $line, $subroutine, $hasargs,
            $evaltext, $is_require, $hints, $bitmask, $hinthash) = caller($far_back);
        ($root) = $subroutine =~ /(\w+)$/;
        
        last unless $root =~ /^_/;
        $far_back ++;
    }
    
    return $root;
}

sub _make_opt_list {
    my ($optional, $processed) = @_;

    my @optional_list;
    foreach my $opt (keys %$optional) {
        if ($opt =~ /^\-/) {
            $opt =~ s/^\-//;
            push @optional_list, $opt;
        }
        else {
            if ($optional->{$opt} =~ /^(?:true|false)$/) {
                push @optional_list, "$opt";
                $processed->{$opt} = ($optional->{$opt} eq 'true') ? 1 : 0;
                next;
            }
            elsif ($optional->{$opt} =~ /\-?\d+\.\d+/) {
                push @optional_list, "$opt=f";
            }
            elsif ($optional->{$opt} =~ /\-?\d+/) {
                push @optional_list, "$opt=i";
            }
            else {
                push @optional_list, "$opt=s";
            }
        }
        
        $processed->{$opt} = $optional->{$opt};
    }
    
    return \@optional_list;
}

1;
