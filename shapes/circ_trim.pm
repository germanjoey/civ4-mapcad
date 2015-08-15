my %params = (
    'centerX' => 0,
    'centerY' => 0,
    'radius' => '0.0'
);

my $gen = sub {
    my ($state, $x, $y, $initial_val) = @_;
   
    my $centerX = $state->{'centerX'};
    my $centerY = $state->{'centerY'};
    my $radius = $state->{'radius'};
   
    my $itt = ($initial_val > 0.5) ? 1 : 0;
    my $distance_to_center = sqrt(($x-$centerX)**2 + ($y-$centerY)**2);
    my $soft_circle_val = 1 - ($distance_to_center-2)/$radius;
    my $intersect = $itt*$soft_circle_val;
    
    my $rand1 = rand(1);
    my $rand2 = rand(1);
    
    return 0 if $itt == 0;
    
    return 0 if $rand1 < 0.2;
    return 1 if $rand2 < 0.20;
    return 1 if $soft_circle_val > 0.5;
    return 0;
};

register_shape(\%params, $gen);