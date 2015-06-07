package Civ4MapCad::Object::Layer;

use strict;
use warnings;

use List::Util qw(min max);
use Civ4MapCad::Map;
use Civ4MapCad::Util qw(deepcopy);

sub new_default {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($name, $width, $height) = @_;
    
    my $obj = {
        'name' => $name,
        'map' => Civ4MapCad::Map->new_default($width, $height),
        'offsetX' => 0,
        'offsetY' => 0,
    };
    
    return bless $obj, $class;
}

sub new_from_import {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($name, $filename) = @_;
    my $obj = {
        'name' => $name,
        'map' => Civ4MapCad::Map->new->import_map($filename),
        'offsetX' => 0,
        'offsetY' => 0,
    };
    
    return bless $obj, $class;
}

sub get_name {
    my ($self) = @_;
    return $self->{'name'};
}

sub rename {
    my ($self, $new_name) = @_;
    $self->{'name'} = $new_name;
}

sub get_group {
    my ($self) = @_;
    return $self->{'member_of'};
}

sub set_membership {
    my ($self, $group) = @_;
    $self->{'member_of'} = $group;
}

# this should only be called when merging a layer into this one, as the merge function returns a new map
sub replace_map {
    my ($self, $map) = @_;
    $self->{'map'} = $map;
}

sub recenter {
    my ($self) = @_;
    $self->{'offsetX'} = 0;
    $self->{'offsetY'} = 0;
}

sub get_width {
    my ($self) = @_;
    return $self->{'map'}->info('grid width');
}

sub get_height {
    my ($self) = @_;
    return $self->{'map'}->info('grid height');
}

sub move {
    my ($self, $byX, $byY) = @_;
    $self->{'offsetX'} = $byX;
    $self->{'offsetY'} = $byY;
}

sub fill_tile {
    my ($self, $x, $y) = @_;
    $self->{'map'}->fill_tile($x, $y);
}

sub delete_tile {
    my ($self, $x, $y) = @_;
    $self->{'map'}->delete_tile($x, $y);
}

# returns a new Layer object - whether the map gets overwritten or not is up to the container object's methods
# TODO: merge signs
sub merge_with_layer {
    my ($self, $othr) = @_;
    
    my $copy = deepcopy($self);
    
    # next, calculate new dimensions
    my $left = min($copy->{'offsetX'}, $othr->{'offsetX'});
    my $right = max($copy->{'offsetX'} + $copy->get_width(), $othr->{'offsetX'} + $othr->get_width()); 
    my $top = min($copy->{'offsetY'}, $othr->{'offsetY'});
    my $bottom = max($copy->{'offsetY'} + $copy->get_height(), $othr->{'offsetY'} + $othr->get_height());
    
    my $width = $right - $left;
    my $height = $bottom - $top;
    
    $copy->{'map'}->expand_dim($width, $height);
    $copy->{'map'}->clear_map();
    $copy->{'map'}->overwrite_tiles($self->{'map'}, $self->{'offsetX'}, $self->{'offsetY'});
    $copy->{'map'}->overwrite_tiles($othr->{'map'}, $othr->{'offsetX'}, $othr->{'offsetY'});
    
    $copy->{'offsetX'} = $left;
    $copy->{'offsetY'} = $top;
    
    return $copy;
}

sub export_layer {
    my ($self, $filename) = @_;
    $self->{'map'}->export_map($filename);
}

1;
