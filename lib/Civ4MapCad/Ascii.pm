package Civ4MapCad::Ascii;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(import_ascii_mask export_ascii_mask import_ascii_mapping_file clean_ascii);

# read in an ascii art shape and turn it into a mask
sub import_ascii_mask {
    my ($filename, $mapping) = @_;

    open (my $ascii, $filename);
    my @lines = <$ascii>;
    close $ascii;
    
    unless ($lines[-1] =~ /[^\n\r]/) {
        pop @lines;
    }
    
    my @canvas;
    my $max_col = 0;
    foreach my $line (@lines) {
        chomp $line;
        $max_col = length($line) if length($line) > $max_col;
    }
    
    foreach my $line (@lines) {
        my @chars = split '', $line;
        my @filtered;
        foreach my $i (0..$#chars) {
            my $char = $chars[$i];
            if (exists $mapping->{$char}) {
                push @filtered, $mapping->{$char};
            }
            else {
                return {
                    'error' => 1,
                    'error_msg' => "Character '$char' was not found in the mapping."
                }
            }
        }
       
        $max_col = ($max_col > $#filtered) ? $max_col : $#filtered;
        push @canvas, \@filtered if @filtered > 0;
    }
    
    # we transpose AND fliptb
    my @transposed;
    for my $y (0..$max_col-1) {
        $transposed[$y] = [];
    }
    
    for my $x (0..$#canvas) {
        my $xx = $#canvas - $x;
        for my $y (0..$#{ $canvas[$x] }) {
            $transposed[$y][$x] = $canvas[$xx][$y];
        }
    }
    
    return {'canvas' => \@transposed};
}

# export a mask as ascii art
sub export_ascii_mask {
    my ($filename, $canvas, $width, $height, $rmapping) = @_;

    open (my $file, '>', $filename) or die $!;
    
    my @transposed;
    foreach my $x (0..$#$canvas) {
        my $xx = $#$canvas - $x;
        foreach my $y (0 .. $#{ $canvas->[$x] }) {
            $transposed[$xx][$y] = $canvas->[$y][$x];
        }
    }
    
    foreach my $x (0..($width-1)) {
        foreach my $y (0..($height-1)) {
            my $value = $transposed[$x][$y];
            my $char = find_nearest_mapping_match($value, $rmapping);
            print $file $char;
        }
        print $file "\n";
    }
    
    close $file;
}

# our mapping error, caused by the fact that mask values are continuous while
# we only have like 30 characters or whatever to put in our ascii art shape
sub find_nearest_mapping_match {
    my ($value, $rmapping) = @_;
    return $rmapping->{$value} if exists $rmapping->{$value};
    
    my $min_diff = 2;
    my $dkey;
    foreach my $k (keys %$rmapping) {
        my $diff = abs($k - $value);
        
        if ($diff < $min_diff) {
            $min_diff = $diff;
            $dkey = $k;
        }
    }
    
    return $rmapping->{$dkey};
}

# a mapping file is a map from characters to a value range for our ascii art mask
sub import_ascii_mapping_file {
    my ($mapping_file) = @_;
    
    my $ret = open (my $map, $mapping_file) or 0;
    if (!$ret) {
        return {
            'error' => 1,
            'error_msg' => "Can't open mapping file: $!"
        };
    }
    
    my @lines = <$map>;
    close $map;
    shift @lines;
    
    my %mapping;
    foreach my $i (0..$#lines) {
        my $line = $lines[$i];
        next unless $line =~ /\w/;
        
        my ($char, $value);
        if ($line =~ /^\s/) {
            $line =~ s/\s//g;
            $value = 0.0;
            $char = ' ';
        }
        else {
            ($char, $value) = split ' ', $line;
            
            unless (defined($char) and defined($value)) {
                return {
                    'error' => 1,
                    'error_msg' => "Error in mapping file: cannot parse line '$line'."
                };
            }
        }
        
        if (exists $mapping{$char}) {
            return {
                'error' => 1,
                'error_msg' => "Error in mapping file: character '$char' maps to two different values."
            };
        }
        
        $mapping{$char} = $value;
    }
    
    return \%mapping;
}

# cleans up an ascii art shape
sub clean_ascii {
    my ($filename) = @_;

    open (my $in, $filename);
    my @lines = <$in>;
    close $in;
    
    open (my $out, '>', "$filename.clean") or die $!;
    
    foreach my $i (0 .. $#lines) {
        my $line = $lines[$i];
        chomp $line;
        my @chars = split '', $line;
        
        foreach my $char (@chars) {
            print $out (($char ne ' ') ? '*' : ' ');
        }
        
        print $out "\n" unless $i == $#lines;
    }
    
    close $out;
}

1;