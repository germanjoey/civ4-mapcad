package Civ4MapCad::Weight;
 
use strict;
use warnings;

# tableref is a reference to $state's tableref, which we need to lookup nested weights
sub new_from_pairs {
    my ($class, $tableref, @pairs) = @_;
 
    my %obj = (
        'tableref' => $tableref,
        'pairs' => \@pairs,
    );
   
    return bless \%obj, $class;
}

sub check_op {
    my ($self) = @_;
    
    foreach my $pair (@{$self->{'pairs'}}) {
        if ($pair->[0] !~ /\<|\<=|==|\>=|\>/) {
            return -1;
        }
    }
    
    return 1;
}


# TODO: check value to make sure its between 0 and 1
sub evaluate {
    my ($self, $value) = @_;
    return _evaluate($value, 1, 2);
}

sub evaluate_inverse {
    my ($self, $value) = @_;
    
    # TODO check to make sure == is the only weight comparator for inverse
    
    return _evaluate($value, 2, 1);
}

our %op = (
    'number' => {
        '<'  => sub { return ($_[0] < $_[1]) },
        '<=' => sub { return ($_[0] <= $_[1]) },
        '==' => sub { return ($_[0] == $_[1]) },
        '>=' => sub { return ($_[0] >= $_[1]) },
        '>'  => sub { return ($_[0] > $_[1]) },
    },
    'terrain' => { # only for inverse
        '==' => sub { return ($_[0] eq $_[1]) },
    },
);

# 

sub _evaluate {
    my ($self, $value, $c, $r) = @_;
    
    my $last = 2;
    foreach my $pair (@{$self->{'pairs'}}) {
        if ($op{$pair->[0]}->($value, $pair->[$c], $last)) {
            if ($pair->[$r] =~ /\%/) {
                my $scaled = ($value - $pair->[$c])/($last - $pair->[$c]);
                return $self->{'tableref'}{$pair->[$r]}->evaluate($scaled);
            }
            
            return $pair->[$r];
        }
        
        $last = $pair->[$c];
    }
    
    if ($self->{'pairs'}[-1][$r] =~ /\%/) {
        my $scaled = ($value)/($last);
        return $self->{'tableref'}{$self->{'pairs'}[-1][$r]}->evaluate($scaled);
    }
    
    return $self->{'pairs'}[-1][$r];
        
}

1;