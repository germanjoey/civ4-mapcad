my %params = (
    'centerX' => 0,
    'centerY' => 0,
    'radius' => 0
);

my $gen = sub {
    my ($state, $x, $y, $initial_val) = @_;
   
    my $centerX = $state->{'centerX'};
    my $centerY = $state->{'centerY'};
    my $radius = $state->{'radius'};
   
    my $distance_to_center = sqrt(($x-$centerX)**2 + ($y-$centerY)**2);
    return ($radius >= $distance_to_center) ? $initial_val : 0;
};

register_shape(\%params, $gen);