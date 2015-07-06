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
        'in_script' => 0,
        'log' => []
    };
    
    return bless $obj, $class;
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
    my ($self, $msg) = @_;
    
    $Text::Wrap::columns = 76;
    print "\n\n";
    print wrap("", "  ", "** ERROR occurred during command:");
    print "\n\n";
    print wrap("    ", "    ", $self->{'current_line'});
    print "\n\n";
    print wrap(" ", "  ", "* " . $msg);
    print "\n\n";
}

sub report_warning {
    my ($self, $msg) = @_;
    
    $Text::Wrap::columns = 76;
    print "\n\n";
    print wrap("", "  ", "* WARNING for command:");
    print "\n\n";
    print wrap("    ", "    ", $self->{'current_line'});
    print "\n\n";
    print wrap(" ", "  ", "* " . $msg);
    print "\n\n";
}

sub report_message {
    my ($self, $msg, $extra_indent) = @_;
    
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