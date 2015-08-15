my %params = (
    'startX' => 0,
    'startY' => 0,
    'size' => 0
);

my $gen = sub {
    my ($state, $x, $y, $initial_val) = @_;
   
    my $startX = $state->{'startX'};
    my $startY = $state->{'startY'};
    my $stopX = $state->{'startX'} + $state->{'size'};
    my $stopY = $state->{'startY'} + $state->{'size'};
   
    if (($x >= $startX) and ($y >= $startY) and ($x < $stopX) and ($y < $stopY)) {
        return $initial_val;
    }
   
    return 0;
};

register_shape(\%params, $gen);