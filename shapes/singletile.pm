my %params = (
    'centerX' => 0,
    'centerY' => 0
);

my $gen = sub {
    my ($state, $x, $y, $initial_val) = @_;
   
    if (($x == $state->{'centerX'}) and ($y ==$state->{'centerY'})) {
        return $initial_val;
    }
   
    return 0;
};


register_shape(\%params, $gen);