package Civ4MapCad::Object::Weight;
 
use strict;
use warnings;

# tableref is a reference to $state's tableref, which we need to lookup nested weights
sub new_from_pairs {
    my ($class, $state, @pairs) = @_;
 
    my %obj = (
        'state' => $state, # we keep a reference to state because we need to flatten a weight when it is evaluated
        'pairs' => \@pairs,
        'flat_pairs' => [],
        'flattened' => 0
    );
   
    return bless \%obj, $class;
}

# call this when you're done with evaluation to clear the cached flat pairs
sub deflate { 
    my ($self) = @_;
    $self->{'flat_pairs'} = [];
    $self->{'flattened'} = 0;
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

# TODO: check value to make sure its between 0 and 1?
sub evaluate {
    my ($self, $value) = @_;
    my $state = $self->{'state'};
    
    unless ($self->{'flattened'}) {
        $self->{'flat_pairs'} = [$self->flatten(1)];
        $self->{'flattened'} = 1;
    }
    
    my %optable = (
        '<'  => sub { return ($_[0] < $_[1]) },
        '<=' => sub { return ($_[0] <= $_[1]) },
        '==' => sub { return ($_[0] == $_[1]) },
        '>=' => sub { return ($_[0] >= $_[1]) },
        '>'  => sub { return ($_[0] > $_[1]) },
    );
    
    foreach my $pair (@{ $self->{'flat_pairs'} }) {
        my ($op, $thresh, $result) = @$pair;
        
        if (! exists $optable{$op}) {
            $state->report_error("Unknown op '$op' when evaluating weight");
            return -1;
        }
        
        if ($optable{$op}->($value, $thresh)) {
            return ($result, $state->get_variable($result, 'terrain'));
        }
    }
    
    return;
}

sub evaluate_inverse {
    my ($self, $tile) = @_;
    my $state = $self->{'state'};
    
    unless ($self->{'flattened'}) {
        $self->{'flat_pairs'} = [$self->flatten(1)];
        $self->{'flattened'} = 1;
    }
    
    my %optable = (
        '==' => sub { return $_[0]->compare($state->{'terrain'}{$_[1]} ) },
    );
    
    foreach my $pair (@{ $self->{'flat_pairs'} }) {
        my ($op, $result, $to_match) = @_;
        
        if (! exists $optable{$op}) {
            $state->report_error("Unknown op '$op' when inverse-evaluating weight");
        }
        
        if ($optable{$op}->($tile, $to_match)) {
            return $result;
        }
    }
    
    return;
}

sub flatten {
    my ($self, $start) = @_;
    my $state = $self->{'state'};
    
    my @to_show;
    my $current_prev = $start;
    
    foreach my $pair (@{ $self->{'pairs'} }) {
        my ($op, $value, $result) = @$pair;
        my $diff = $current_prev - $value;
            
        if ($result =~ /^\%/) {
            my $result_weight = $state->get_variable($result, 'weight');
            
            my @sub_show = $result_weight->flatten($current_prev);
            
            foreach my $sub_pair (@sub_show) {
                my ($sub_op, $sub_value, $sub_result) = @$sub_pair;
                my $calc = sprintf "%6.4f", $sub_value*$diff + $value;
                push @to_show, [$sub_op, $calc, $sub_result];
            }
        }
        else {
            push @to_show, [$op, $value, $result];
        }
        
        $current_prev = $value;
    }
    
    return @to_show;
}

1;