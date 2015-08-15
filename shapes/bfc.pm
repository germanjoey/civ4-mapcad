my %params = (
    'centerX' => 0,
    'centerY' => 0
);

my $gen = sub {
    my ($state, $x, $y, $initial_val) = @_;
   
    my $adx = abs($state->{'centerX'} - $x);
    my $ady = abs($state->{'centerY'} - $y);
    
    return 0 if ($adx == 2) and ($ady == 2);
    return $initial_val if ($adx <= 2) and ($ady <= 2);
    
    return 0;
};

register_shape(\%params, $gen);