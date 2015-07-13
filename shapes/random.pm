my %params = (
    'min' => 0,
    'max' => 1
);

my $gen = sub {
    my ($state, $x, $y) = @_;
    
    my $max = $state->{'max'};
    my $min = $state->{'min'};
    
    return rand(1)*($max - $min) + $min;
};

register_shape(\%params, $gen);