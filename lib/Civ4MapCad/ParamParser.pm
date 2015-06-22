package Civ4MapCad::ParamParser;

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

use Getopt::Long qw(GetOptionsFromArray :config pass_through);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($state, $raw_params, $param_spec) = @_;
    
    my $processed = _process($state, $raw_params, $param_spec);
    return bless $processed, $class;
}
    
sub _process {
    my ($state, $raw_params, $param_spec) = @_;

    my $optional = $param_spec->{'optional'};
    my $required = $param_spec->{'required'} || [];
    my $has_shape_params = $param_spec->{'has_shape_params'};
    
    my $has_result = $param_spec->{'has_result'};
    my $allow_implied_result = $param_spec->{'allow_implied_result'};
    my %processed_params = ('error' => 0);
    
    # figure out result
    my $implied_result = 0;
    if ((@$raw_params >= 2) and ($raw_params->[-2] eq '=>')) {
        if (! $has_result) {
            $state->report_error("a result is specified, but this command does not produce one.");
            $processed_params{'error'} = 1;
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
    # TODO: combine strings into a single element
    my @preproc;
    
    my $current_string = '';
    my $open_string = 0;
    
    foreach my $raw (@$raw_params) {
        if (($open_string == 1) or ($raw =~ /^\"/)) {
            $open_string = 1;
            
            $current_string .= $raw;
            
            if ($raw =~ /\"$/) {
                push @preproc, $current_string;
                
                $open_string = 0;
                $current_string = '';
            }
            
            next;
        }
    
        $raw =~ s/^\-+/-/;
        $raw =~ s/^-/--/;
        
        if ($raw eq '=>') {
            $state->report_error("a result operator was specified in a way that does not make sense.");
            $processed_params{'error'} = 1;
            return \%processed_params;
        }
        
        push @preproc, $raw;
    }
    
    if ($open_string) {
        $state->report_error("parse error, string was found to have an open quote.");
        $processed_params{'error'} = 1;
        return \%processed_params;
    }
    
    # get optional flags
    my $optional_list = _make_opt_list ($optional, \%processed_params);
    GetOptionsFromArray(\@preproc, \%processed_params, @$optional_list);
    if ((!$has_shape_params) && (@preproc != @$required)) {
        $state->report_error("this command was supplied an incorrect number of required parameters.");
        $processed_params{'error'} = 1;
        return \%processed_params;
    }
    $processed_params{'_required'} = [] if @preproc > 0;
    
    my $i=0;
    my @shape_param_list;
    
    # remnants of @preproc are the required params; resolve those to variables
    while (1) {
        last if $i > $#preproc;
    
        if ($preproc[$i] =~ /^\-\-/) {
            push @shape_param_list, $preproc[$i];
            push @shape_param_list, $preproc[$i+1];
            $i += 2;
            next;
        }
    
        my $expected_type = $required->[$i];
        
        if ($expected_type eq 'int') {
            unless ($preproc[$i] =~ /^[-+]?\d+$/) {
                $state->report_error("parameter '$preproc[$i]' was expected to be a floating point value but yet is not.");
                $processed_params{'error'} = 1;
                return \%processed_params;
            };
            
            push @{ $processed_params{'_required'} }, $preproc[$i];
            $i++;
            next;
        }
        elsif ($expected_type eq 'float') {
            unless ($preproc[$i] =~ /^[-+]?\d+(?:\.\d+(?:[eE][-+]?\d+))?$/) {
                $state->report_error("parameter '$preproc[$i]' was expected to be a floating point value but yet is not.");
                $processed_params{'error'} = 1;
                return \%processed_params;
            };
        
            push @{ $processed_params{'_required'} }, $preproc[$i];
            $i++;
            next;
        }
        
        elsif ($expected_type eq 'str') {
            if (($preproc[$i] !~ /^"/) or ($preproc[$i] !~ /"$/)) {
                $state->report_error("a string was expected for '$preproc[0]'; all strings must be enclosed in double-quotes.");
                $processed_params{'error'} = 1;
                return \%processed_params;
            }
        
            $preproc[$i] =~ s/^"//;
            $preproc[$i] =~ s/"$//;
            push @{ $processed_params{'_required'} }, $preproc[$i];
            $i++;
            next;
        }
        
        my $name = $state->check_vartype($preproc[$i], $expected_type);
        unless ($name ne '-1') {
            $processed_params{'error'} = 1;
            return \%processed_params;
        };
        
        if (! $state->variable_exists($name, $expected_type)) {
            if ($expected_type eq 'layer') {
                my ($groupname) = $name =~ /^(\w+)/;
                my ($layername) = $name =~ /^\w+\.(\w+)/;
                
                if (! $state->variable_exists($groupname, 'group')) {
                    $state->report_error("a variable of type group named '\$$groupname' does not exist.");
                    $processed_params{'error'} = 1;
                    return \%processed_params;
                }
                else {
                    $state->report_error("group '\$$groupname' does not contain a layer named '$layername'.");
                    $processed_params{'error'} = 1;
                    return \%processed_params;
                }
            }
            else {
                my %prefix = ('group' => '$', 'mask' => '@', 'weight' => '%', 'shape' => '*');
                $state->report_error("a variable of type '$expected_type' named '$prefix{$expected_type}$name' does not exist.");
                $processed_params{'error'} = 1;
                return \%processed_params;
            }
        }
        
        push @{ $processed_params{'_required'} }, $state->get_variable($name, $expected_type);
        
        $i ++;
    }
    
    # finally, if we have an implied_result, set that to be the command's destination
    if ($has_result && $implied_result) {
        my $result_name = $state->check_vartype($preproc[0], $required->[0]);
        unless ($result_name ne '-1') {
            $processed_params{'error'} = 1;
            return \%processed_params;
        };
        
        $processed_params{'_result'} = $result_name;
        $processed_params{'_result_type'} = $required->[0];
    }
    
    # otherwise, we set it to the new destination
    elsif ($has_result and exists($processed_params{'_result'})) {
        my $name = $state->check_vartype($processed_params{'_result'}, $has_result);
        
        unless ($name ne '-1') {
            $processed_params{'error'} = 1;
            return \%processed_params;
        };
        
        $processed_params{'_result'} = $name;
        $processed_params{'_result_type'} = $has_result;
    }
    
    # a result was expected but none was supplied!
    elsif ($has_result) {
        $state->report_error("a result is produced from this command but no target variable was given.");
        $processed_params{'error'} = 1;
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
    
    return \%processed_params;
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
            if ($optional->{$opt} =~ /\-?\d+\.\d+/) {
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

sub get_named {
    my ($self, $name) = @_;
    return $self->{$name};
}

=head1

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($spec) = @_;
    
    my $obj = {
        'optional' => $spec->{'optional'} || {},
        'required' => $spec->{'required'} || [],
        'allow_implied_result' => $spec->{'allow_implied_result'} || 0,
        'has_result' => $spec->{'has_result'} || 0,
        'has_shape_params' => $spec->{'has_result'} || 0,
    };
    
    return bless $obj, $class;
}

sub parse {
    my ($raw_params) = @_;
    
    my $optional = $self->{'optional'};
    my $required = $self->{'required'};
    my $has_shape_params = $self->{'shape_params'};
    
    my $has_result = $self->{'has_result'};
    my $allow_implied_result = $self->{'allow_implied_result'};
    my %processed_params = ('error' => 0);
    
    # figure out result
    my $implied_result = 0;
    if ((@$raw_params >= 2) && ($raw_params->[-2] eq '=>')) {
        if (! $has_result) {
            $state->report_error("a result is specified, but this command does not produce one.");
            $processed_params{'error'} = 1;
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
    foreach my $raw (@$raw_params) {
        $raw =~ s/^\-+/-/;
        $raw =~ s/^-/--/;
        
        if ($raw eq '=>') {
            $state->report_error("a result operator was specified in a way that does not make sense.");
            $processed_params{'error'} = 1;
            return \%processed_params;
        }
        
        push @preproc, $raw;
    }
    
    # get optional flags
    my $optional_list = make_opt_list ($optional, \%processed_params);
    GetOptionsFromArray(\@preproc, \%processed_params, @$optional_list);
    if ((!$has_shape_params) && (@preproc != @$required)) {
        $state->report_error("this command was supplied an incorrect number of required parameters.");
        $processed_params{'error'} = 1;
        return \%processed_params;
    }
    $processed_params{'_required'} = [] if @preproc > 0;
    
    my $i=0;
    my @shape_param_list;
    
    # remnants of @preproc are the required params; resolve those to variables
    while (1) {
        last if $i > $#preproc;
    
        if ($preproc[$i] =~ /^\-\-/) {
            push @shape_param_list, $preproc[$i];
            push @shape_param_list, $preproc[$i+1];
            $i += 2;
            next;
        }
    
        my $type = $required->[$i];
        
        my $name = check_vartype($state, $preproc[$i], $type);
        unless ($name ne '-1') {
            $processed_params{'error'} = 1;
            return \%processed_params;
        };
        
        if (! exists $state->{$type}{$name}) {
            if ($type eq 'layer') {
                my ($groupname) = $name =~ /^(\w+)/;
                my ($layername) = $name =~ /^\w+\.(\w+)/;
                
                if (! exists $state->{'group'}{$groupname}) {
                    $state->report_error("a variable of type group named '\$$groupname' does not exist.");
                    $processed_params{'error'} = 1;
                    return \%processed_params;
                }
                else {
                    $state->report_error("group '\$$groupname' does not contain a layer named '$layername'.");
                    $processed_params{'error'} = 1;
                    return \%processed_params;
                }
            }
            else {
                my %prefix = ('group' => '$', 'mask' => '@', 'weight' => '%', 'shape' => '*');
                $state->report_error("a variable of type '$type' named '$prefix{$type}$name' does not exist.");
                $processed_params{'error'} = 1;
                return \%processed_params;
            }
        }
        
        push @{ $processed_params{'_required'} }, $state->{$type}{$name};
        
        $i ++;
    }
    
    # finally, if we have an implied_result, set that to be the command's destination
    if ($has_result && $implied_result) {
        my $result_name = check_vartype($state, $preproc[0], $required->[0]);
        unless ($result_name ne '-1') {
            $processed_params{'error'} = 1;
            return \%processed_params;
        };
        
        $processed_params{'_result'} = $result_name;
        $processed_params{'_result_type'} = $required->[0];
    }
    
    # otherwise, we set it to the new destination
    elsif ($has_result and exists($processed_params{'_result'})) {
        my $name = $state->check_vartype($processed_params{'_result'}, $has_result);
        
        unless ($name ne '-1') {
            $processed_params{'error'} = 1;
            return \%processed_params;
        };
        
        $processed_params{'_result'} = $name;
        $processed_params{'_result_type'} = $has_result;
    }
    
    # a result was expected but none was supplied!
    elsif ($has_result) {
        $state->report_error("a result is produced from this command but no target variable was given.");
    }
    
    # this should only be called for new_mask_from_shape, which has a shape as its first (and only) required argument
    if ($has_shape_params) {
        my $shape_name = $preproc[0];
    
        my %shape_args;
        my $shape_param_spec = $state->{'shape_param'}{$preproc[0]};
        my $shape_opts = make_opt_list($shape_param_spec, \%shape_args);
        
        GetOptionsFromArray(\@shape_param_list, \%shape_args, @$shape_opts);
        $processed_params{'_shape_params'} = \%shape_args;
    }
    
    $self->{'processed'} = 1;
    $self->{'_processed'} = \%processed_params;
}

sub make_opt_list {
    my ($optional, $processed) = @_;

    my @optional_list;
    foreach my $opt (keys %$optional) {
        if ($opt =~ /^\-/) {
            $opt =~ s/^\-//;
            push @optional_list, $opt;
        }
        else {
            if ($optional->{$opt} =~ /\-?\d+\.\d+/) {
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

=cut

1;
