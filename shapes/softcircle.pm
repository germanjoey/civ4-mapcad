my %params = (
    'centerX' => 0,
    'centerY' => 0,
    'radius' => 0
);

my $gen = sub {
    my ($state, $x, $y) = @_;
   
    my $centerX = $state->{'centerX'};
    my $centerY = $state->{'centerY'};
    my $radius = $state->{'radius'};
   
    my $distance_to_center = sqrt(($x-$centerX)**2 + ($y-$centerY)**2);
    my $value = 1 - ($distance_to_center-2)/$radius;
    return $value;
};

register_shape(\%params, $gen);