my %params = (
    'startX' => 0,
    'startY' => 0
);

my $gen = sub {
    my ($state, $x, $y) = @_;
    #my $x = $tile->get('x');
    #my $y = $tile->get('y');
   
    my $startX = $state->{'startX'};
    my $startY = $state->{'startY'};
    my $stopX = $state->{'startX'} + $state->{'width'};
    my $stopY = $state->{'startY'} + $state->{'height'};
   
    if (($x >= $startX) and ($y >= $startY) and ($x < $stopX) and ($y < $stopY)) {
        return 1;
    }
   
    return 0;
};

register_shape(\%params, $gen);