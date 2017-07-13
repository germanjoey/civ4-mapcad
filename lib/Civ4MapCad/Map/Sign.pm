package Civ4MapCad::Map::Sign;

use strict;
use warnings;

our @fields = qw(plotX plotY playerType caption);
our %field_names;
@field_names{@fields} = (1) x @fields;

use Civ4MapCad::Util qw(write_block_data);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $obj = bless {}, $class;
    
    return $obj;
}

sub new_default {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $obj = bless {}, $class;
    
    return $obj;
}

sub clear {
    my ($self) = @_;
    delete $self->{$_} foreach (@fields);
}

sub get {
    my ($self, $key) = @_;
    return $self->{$key};
}

sub set {
    my ($self, $key, $value) = @_;
    $self->{$key} = $value;
}

sub parse {
    my ($self, $fh) = @_;
    
    # begin unit is already found
    while (1) {
        my $line = <$fh>;
        next if $line !~ /\w/;
        next if $line =~ /^\s*#/;
        return if $line =~ /EndSign/i;
        chomp $line;
        $line =~ s/^\s*//;
        $line =~ s/\s*$//;
        
        my ($name, @rest) = split '=', $line;
        $self->set($name, join('=', @rest));
    }
}

sub writeout {
    my ($self, $fh) = @_;
    print $fh "BeginSign\n";
    
    foreach my $field (@fields) {
        write_block_data($self, $fh, 1, $field);
    }
    
    print $fh "EndSign\n";
}


1;