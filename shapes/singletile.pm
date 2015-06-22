my %params = (
    'centerX' => 0,
    'centerY' => 0
);

my $gen = sub {
    my ($state, $x, $y) = @_;
   
    if (($x == $state->{'centerX'}) and ($y ==$state->{'centerY'})) {
        return 1;
    }
   
    return 0;
};


register_shape(\%params, $gen);