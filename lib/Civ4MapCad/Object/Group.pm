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
    
    $self->add_layer(Civ4MapCad::Object::Layer->new_from_import($name, $filename));
    $self->{'width'} = $self->{'layers'}{$name}->get_width;
    $self->{'height'} = $self->{'layers'}{$name}->get_height;
    
    return $self;
}

sub get_name {
    my ($self) = @_;
    return $self->{'name'};
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
    my ($self, $layer) = @_;
    my $layer_name = $layer->get_name();
    
    if (exists $self->{'layers'}{$layer_name}) {
        # WARNING: ovewriting!
        $self->{'layers'}{$layer_name} = $layer;
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
        $copy->add_layer($layer);
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
    
    $self->{'priority'}{$old_layer_name} = $p;
    $self->{'layers'}{$old_layer_name} = $l;
    
    return 1;
}
 
sub increase_priority {
    my ($self, $layer_name) = @_;
   
    if ($self->{'priority'}{$layer_name} > 0) {
        $self->set_layer_priority($layer_name, $self->{'priority'}{$layer_name} - 1);
    }
}
 
sub decrease_priority {
    my ($self, $layer_name) = @_;
   
    $self->set_layer_priority($layer_name, $self->{'priority'}{$layer_name} + 1);
}
 
sub set_layer_priority {
    my ($self, $layer_name, $new_priority) = @_;
   
    foreach my $name (keys %{ $self->{'layers'} }) {
        if ($self->{'priority'}{$name} >= $new_priority) {
            $self->{'priority'}{$name} = $self->{'priority'}{$name} + 1;
            if (($self->{'priority'}{$name}) >= $self->{'max_priority'}) {
                $self->{'max_priority'} = $self->{'priority'}{$name};
            }
        }        
    }
   
    $self->{'priority'}{$layer_name} = $new_priority;
    if (($self->{'priority'}{$layer_name}) >= $self->{'max_priority'}) {
        $self->{'max_priority'} = $self->{'priority'}{$layer_name};
    }
   
    return 1;
}

sub get_layer_priority {
    my ($self, $layer_name) = @_;
 
    return $self->{'priority'}{$layer_name};
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
        my @remaining_layers = $copy->get_layer_names();
        last if @remaining_layers == 1;
       
        $copy->merge_two_and_replace($remaining_layers[0], $remaining_layers[1]);
    }
   
    # cleanup priority list
    my @remaining_layers = $copy->get_layer_names();
    $copy->{'priority'}{$remaining_layers[0]} = 0;
    $self->{'max_priority'} = 0;
   
    return $copy;
}

sub find_difference {
    my ($self, $other_group) = @_;
    
    die "not yet implemented!";
}

sub normalize_starts {
    my ($self) = @_;
    
    # first normalize each layer
    foreach my $layer (keys %{ $self->{layers} }) {
        $self->{'layers'}{$layer}->normalize_starts();
    }
    
    my %duplicates;
    my %starts_found;
    my $all_starts = $self->find_starts();
    
    foreach my $layer_set (@$all_starts) {
        my $layer_name = $layer_set->[0];
        
        foreach my $start (@{ $layer_set->[1] }) {
            my ($x, $y, $owner) = @$start;
            
            if (exists $starts_found{$owner}) {
                $duplicates{$owner} = 1;
                push @{ $starts_found{$owner} }, $layer_name;
            }
            else {
                $starts_found{$owner} = [$layer_name];
            }
        }
    }
    
    foreach my $duplicate_start (keys %duplicates) {
        my @dups = $starts_found{$duplicate_start};
        my $assigned_layer = shift @dups;
        while (1) {
            last unless @dups > 0;
            my $layer = shift @dups;
            
            my $new_id = _get_next_open_start_id(\%starts_found);
            $starts_found{$new_id} = 1;
            $self->{'layers'}{$layer}->reassign_start($duplicate_start, $new_id);
        }
    }
    
    return 1;
}

sub _get_next_open_start_id {
    my ($starts_found) = @_;
    
    my $id = 0;
    while (1) {
        last unless exists $starts_found->{$id};
        $id ++;
    }
    return $id;
}

sub find_starts {
    my ($self) = @_;

    my @all_starts;
    foreach my $layer ($self->get_layers()) {
        push @all_starts, [$layer->get_name(), $layer->find_starts()];
    }
    
    return \@all_starts;
}

sub reassign_start {
    my ($self, $old, $new) = @_;

    foreach my $layer ($self->get_layers()) {
        $layer->reassign_start($old, $new);
    }
}

sub strip_all_units {
    my ($self) = @_;

    foreach my $layer ($self->get_layers()) {
        $layer->strip_all_units();
    }
}

sub strip_nonsettlers {
    my ($self) = @_;

    foreach my $layer ($self->get_layers()) {
        $layer->strip_nonsettlers();
    }
}

sub add_scouts_to_settlers {
    my ($self) = @_;

    foreach my $layer ($self->get_layers()) {
        $layer->add_scouts_to_settlers();
    }
    
    return 1;
}

# its assumed that the group is normalized by this point
sub extract_starts_with_mask {
    my ($self, $mask) = @_;
    
    my $all_starts = $self->find_starts();
    
    my @sorted_starts;
    # sort starts
    foreach my $start (@$all_starts) {
        push @sorted_starts, map {[$start->[0], @$_]} @{ $start->[1] };
    }
    
    @sorted_starts = sort { $b->[3] <=> $a->[3] } @sorted_starts;
    
    foreach my $start (@sorted_starts) {
        my ($layer_name, $x, $y, $owner) = @$start;
        my $offsetX = $x - int($mask->get_width()/2);
        my $offsetY = $y - int($mask->get_height()/2);
        
        my $start_layer = $self->{'layers'}{$layer_name}->select_with_mask($mask, $offsetX, $offsetY);
        $start_layer->set_player_from_layer($owner, $self->{'layers'}{$layer_name});
        $start_layer->rename("start" . $owner);
        $start_layer->strip_hidden_strategic();
        $start_layer->strip_victories();
        $start_layer->set_difficulty($main::config{'difficulty'});
        
        my $p = $self->{'priority'}{$layer_name};
        $self->add_layer($start_layer);
        $self->set_layer_priority($start_layer->get_name(), $start_layer, $p);
    }
    
    return 1;
}

sub export {
    my ($self, $output_dir) = @_;

    foreach my $layer ($self->get_layers()) {
        my $path = $output_dir . "/" . $self->get_name() . "." . $layer->get_name() . ".CivBeyondSwordWBSave";
        
        my $strip = 1;
        if ($self->get_name() eq $layer->get_name()) {
            $strip = 0;
            $path = $output_dir . "/" . $self->get_name() . ".CivBeyondSwordWBSave" ;
            $path =~ s/\.CivBeyondSwordWBSave/.out.CivBeyondSwordWBSave/ if -e $path;
        }
        
        $layer->reduce_players();
        $layer->add_dummy_start() if $layer->num_players() == 1;
        $layer->export_layer($path);
    }
    
    return 1;
}

1;
