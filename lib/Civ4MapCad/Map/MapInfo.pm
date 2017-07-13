package Civ4MapCad::Map::MapInfo;

use strict;
use warnings;

our @fields = ('grid width', 'grid height', 'top latitude', 'bottom latitude', 'wrap X', 'wrap Y', 'world size', 'climate', 'sealevel', 'num plots written', 'num signs written', 'Randomize Resources');
our %field_names;
@field_names{@fields} = (1) x @fields;

use Civ4MapCad::Util qw(write_block_data);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    
    my $obj = bless { 'wrap X' => 0, 'wrap Y' => 0 }, $class;
    return $obj;
}

sub new_default {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $obj = bless { 'wrap X' => 0, 'wrap Y' => 0 }, $class;
    
    my ($width, $height) = @_;
    $obj->set_default($width, $height);
    return $obj;
}

sub clear {
    my ($self) = @_;
    delete $self->{$_} foreach (@fields);
    $self->{'Civics'} = [];
}

sub set_default {
    my ($self, $width, $height) = @_;
    
    $self->set('grid width', $width);
    $self->set('grid height', $height);
    $self->set('top latitude', 30);
    $self->set('bottom latitude', 30);
    $self->set('wrap X', 1);
    $self->set('wrap Y', 1);
    $self->set('world size', 'WORLDSIZE_STANDARD');
    $self->set('climate', 'CLIMATE_TEMPERATE');
    $self->set('sealevel', 'SEALEVEL_MEDIUM');
    $self->set('num plots written', $width*$height);
    $self->set('num signs written', 0);
    $self->set('Randomize Resources', 'false');
}

sub get {
    my ($self, $key) = @_;
    return unless exists $self->{$key};
    return $self->{$key};
}

sub set {
    my ($self, $key, $value) = @_;
    
    #if ((($key eq 'wrap X') or ($key eq 'wrap Y')) and ($value == 0)) {
    #    delete $self->{$key};
    #}
    
    $self->{$key} = $value;
}

sub parse {
    my ($self, $fh) = @_;
    
    # begin unit is already found
    while (1) {
        my $line = <$fh>;
        next if $line !~ /\w/;
        next if $line =~ /^\s*#/;
        return if $line =~ /EndMap/i;
        chomp $line;
        $line =~ s/^\s*//;
        $line =~ s/\s*$//;
        
        my ($name, $value) = split '=', $line;
        $self->set($name, $value);
    }
}

sub writeout {
    my ($self, $fh) = @_;
    print $fh "BeginMap\n";
    
    if ((exists $self->{'wrap X'}) and ($self->{'wrap X'} == 0)) {
        delete $self->{'wrap X'};
    }
    
    if ((exists $self->{'wrap Y'}) and ($self->{'wrap Y'} == 0)) {
        delete $self->{'wrap Y'};
    }
    
    foreach my $field (@fields) {
        write_block_data($self, $fh, 1, $field);
    }
    
    print $fh "EndMap\n";
}


1;