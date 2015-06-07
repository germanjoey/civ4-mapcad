package Civ4MapCad::State;

use strict;
use warnings;

use Text::Wrap qw(wrap);

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
    };
    
    return bless $obj, $class;
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
    return $self->{'shape_params'}{$shape_name};
}

sub set_shape_params {
    my ($self, $shape_name, $params) = @_;
    $self->{'shape_params'}{$shape_name} = $params;
}

sub get_variable {
    my ($self, $name, $type) = @_;
    return $self->{$type}{$name};
}

sub set_variable {
    my ($self, $name, $type, $value) = @_;
    $self->{$type}{$name} = $value;
    
    if ($type eq 'group') {
        foreach my $layer ($value->get_layers()) {
            my $layername = $layer->get_name();
            $self->{'layer'}{"\$$name.$layername"} = $layer;
        }
    }
}

sub variable_exists {
    my ($self, $name, $expected_type) = @_;
    
    if ($expected_type eq 'layer') {
        my ($groupname) = $name =~ /^(\w+)/;
        my ($layername) = $name =~ /^\w+\.(\w+)/;
                
        if (exists($self->{'group'}{$groupname})) {
            return $self->{'group'}{$groupname}->layer_exists($layername);
        }
        
        return 0;
    }
    
    return exists($self->{$expected_type}{$name});
}

sub check_vartype {
    my ($self, $raw_name, $expected_type) = @_;
    
    my ($sigil) = $raw_name =~ /^([\$\%\@\*])/;
    my %prefix = ('$' => 'group', '@' => 'mask', '%' => 'weight', '*' => 'shape');
    unless (defined($sigil)) {
        report_error($self, "unknown variable type for '$raw_name'.");
        return -1;
    }
    
    my $actual = $prefix{$sigil};
    
    if ($raw_name =~ /\./) {
        if ($actual eq 'group') {
            $actual = 'layer';
        }
        else {
            report_error($self, "unknown variable type for '$raw_name'.");
            return -1;
        }
    }
    
    if ($sigil eq '$') {
        if (($expected_type eq 'layer') && ($raw_name !~ /\./)) {
            report_error($self, "parameter $raw_name is expected to be of type 'layer' but was actually parsed as type 'group'.");
            return -1;
        }
        elsif (($expected_type eq 'group') && ($raw_name =~ /\./)) {
            report_error($self, "variable $raw_name is expected to be of type 'group' but was actually parsed as type 'layer'.");
            return -1;
        }
    }
    elsif (($sigil eq '@') and ($expected_type ne 'mask')) {
        report_error($self, "variable $raw_name is expected to be of type 'mask' but was actually parsed as type '$actual'.");
        return -1;
    }
    elsif (($sigil eq '%') and ($expected_type ne 'weight')) {
        report_error($self, "variable $raw_name is expected to be of type 'weight' but was actually parsed as type '$actual'.");
        return -1;
    }
    elsif (($sigil eq '*') and ($expected_type ne 'shape')) {
        report_error($self, "variable $raw_name is expected to be of type 'shape' but was actually parsed as type '$actual'.");
        return -1;
    }
    
    return $raw_name;
}

# TODO: replace all error printing with this
sub report_error {
    my ($state, $msg) = @_;
    
    $Text::Wrap::columns = 76;
    print "\n";
    print wrap("", "  ", "** ERROR occurred during command \"$state->{'current_line'}\":\n");
    print wrap("  ", "  ", $msg);
    print "\n\n";
}

sub report_warning {
    my ($state, $msg) = @_;
    
    $Text::Wrap::columns = 76;
    print "\n";
    print wrap("", "  ", "* WARNING for command \"$state->{'current_line'}\":");
    print "\n";
    print wrap("  ", "  ", $msg);
    print "\n\n";
}

1;