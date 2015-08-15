my %params = (
    'min' => '0.0',
    'max' => '1.0'
);

my $gen = sub {
    my ($state, $x, $y, $initial_val) = @_;
    
    my $max = $state->{'max'};
    my $min = $state->{'min'};
    
    return $initial_val*rand(1)*($max - $min) + $min;
};

register_shape(\%params, $gen);