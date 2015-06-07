package Civ4MapCad::Object::Group;
 
use strict;
use warnings;
 
use Civ4MapCad::Object::Layer;
use Civ4MapCad::Util qw(deepcopy);
 
sub new_blank {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($name, $width, $height) = @_;
   
    my $obj = {
        'name' => $name,
        'layers' => {}, # indexed by name
        'width' => 0,
        'height' => 0,
        'max_priority' => -1,
        'priority' => {}, # indexed by name, value is priority. bottom layer (highest priority, which is the lowest number) defines map settings
    };
   
    return bless $obj, $class;
}
 
sub new_from_import {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($filename) = @_;
   
    my $obj = {
        'layers' => {},
        'width' => 0,
        'height' => 0,
        'max_priority' => -1,
    };
   
    my $self = bless $obj, $class;
    my ($name) = $filename =~ /(\w+)\.\w+$/;
    $self->{'name'} = $name;
    
    $self->add_layer($name, Civ4MapCad::Object::Layer->new_from_import($filename));
    $self->{'width'} = $self->{'layers'}{$name}->get_width;
    $self->{'height'} = $self->{'layers'}{$name}->get_height;
    
    return $self;
}

sub get_layer {
    my ($self, $layer_name) = @_;
    return $self->{'layers'}{$layer_name};
}

# starting with the highest_priority first
sub get_layers {
    my ($self) = @_;
    my @layers = map { $self->{'layers'}{$_} } $self->get_layer_names();
    return @layers;
}

sub get_layer_names {
    my ($self) = @_;
    my @names = keys %{ $self->{'layers'} };
    my @order = sort { $self->{'priority'}{$a} <=> $self->{'priority'}{$b} } @names;
    return @order;
}
 
sub add_layer {
    my ($self, $layer_name, $layer) = @_;
    
    if (exists $self->{'layers'}{$layer_name}) {
        # ERROR! layer named $layer_name already exists
        return -1;
    }
   
    $self->{'max_priority'} ++;
    $self->{'layers'}{$layer_name} = $layer;
    $self->{'priority'}{$layer_name} = $self->{'max_priority'};
   
    if ($self->{'max_priority'} == 0) {
        $self->{'width'} = $layer->get_width();
        $self->{'height'} = $layer->get_height();
    }
    
    $layer->set_membership($self);
   
    return 1;
}

sub add_groups {
    my ($self, $other_group) = @_;
    
    my $copy = deepcopy($self);
    my $othername = $other_group->get_name();
    
    my @layers = $other_group->get_layers();
    foreach my $layer (@layers) {
        my $name = $layer->get_name();
        if (exists $copy->{'layers'}{$name}) {
            $name = $othername . "_" . $name;
            $layer->rename($name);
        }
        $copy->add_layer($name, $layer);
    }
    
    return $copy;
}

# expand numbers can be negative
sub change_canvas_size {
    my ($self, $expand_top_by, $expand_left_by, $expand_bottom_by, $expand_right_by) = @_;
   
    $self->{'width'} = $self->{'width'} + ($expand_left_by + $expand_right_by);
    $self->{'height'} = $self->{'height'} + ($expand_top_by + $expand_bottom_by);
   
    if (($expand_top_by != 0) || ($expand_left_by != 0)) {
        foreach my $name (keys %{ $self->{'layers'} }) {
            $self->{'layers'}{$name}->move($expand_top_by, $expand_left_by);
        }
    }
}
 

sub rename_layer {
    my ($self, $old_layer_name, $new_layer_name) = @_;
    
    if (exists $self->{'layers'}{$new_layer_name}) {
        # ERROR! layer named $new_layer_name already exists
        return -1;
    }
   
    my $p = $self->{'priority'}{$old_layer_name};
    my $l = $self->{'layers'}{$old_layer_name};
    
    delete $self->{'priority'}{$old_layer_name};
    delete $self->{'layers'}{$old_layer_name};
    
    $self->{'priority'}{$old_layer_name} = $p
    $self->{'layers'}{$old_layer_name} = $l;
    
    return 1;
}
 
sub increase_priority {
    my ($self, $layer_name) = @_;
   
    if ($self->{'priority'}{$name} > 0) {
        $self->set_layer_priority($layer_name, $self->{'priority'}{$name} - 1);
    }
}
 
sub decrease_priority {
    my ($self, $layer_name) = @_;
   
    $self->set_layer_priority($layer_name, $self->{'priority'}{$name} + 1);
}
 
sub set_layer_priority {
    my ($self, $layer_name, $new_priority) = @_;
   
    foreach my $name (keys %{ $self->{'layers'} }) {
        if ($self->{'priority'}{$name} >= $new_priority) {
            $self->{'priority}{$name} = $self->{'priority}{$name} + 1;
            if (($self->{'priority}{$name}) >= $self->{'max_priority'}) {
                $self->{'max_priority'} = $self->{'priority}{$name};
            }
        }        
    }
   
    $self->{'priority}{$layer_name} = $new_priority;
    if (($self->{'priority'}{$layer_name}) >= $self->{'max_priority'}) {
        $self->{'max_priority'} = $self->{'priority'}{$layer_name};
    }
   
    return 1;
}
 
sub merge_two_and_replace {
    my ($self, $layer1_name, $layer2_name) = @_;
   
    my $layer1 = $self->{'layers'}{$layer1_name};
    my $layer2 = $self->{'layers'}{$layer2_name};
   
    delete $self->{'priority'}{$layer2_name};
    delete $self->{'layers'}{$layer2_name};
   
    my $merged = $layer1->merge($layer2);
    $self->{'layers'}{$layer1_name} = $merged;
   
    return 1;
}
 
sub merge_all {
    my ($self) = @_;
   
    my $copy = deepcopy($self);
   
    while (1) {
        my @remaining = $copy->get_layer_names();
        last if @remaining_layers == 1;
       
        $copy->merge_two_and_replace($remaining[0], $remaining[1]);
    }
   
    # cleanup priority list
    my @remaining = $copy->get_layer_names();
    $copy->{'priority'}{$remaining[0]} = 0;
    $self->{'max_priority'} = 0;
   
    return $copy;
}

sub find_difference {
    my ($self, $other_group) = @_;
    
    die "not yet implemented!";
}