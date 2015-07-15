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
        'wrapX' => 1,
        'wrapY' => 1,
        'layers' => {}, # indexed by name
        'width' => $width,
        'height' => $height,
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
        'wrapX' => 0,
        'wrapY' => 0,
        'width' => 0,
        'height' => 0,
        'max_priority' => -1,
    };
   
    my $self = bless $obj, $class;
    my ($name) = $filename =~ /(\w+)\.\w+$/;
    $self->{'name'} = $name;
    my $layer = Civ4MapCad::Object::Layer->new_from_import($name, $filename);
    
    # error on import
    if (ref($layer) eq '') {
        return $layer;
    };
    
    $self->{'width'} = $layer->get_width();
    $self->{'height'} = $layer->get_height();
    $self->{'wrapX'} = ($layer->wrapsX()) ? 1 : 0;
    $self->{'wrapY'} = ($layer->wrapsY()) ? 1 : 0;
    
    $self->add_layer($layer);
    return $self;
}

sub wrapsX {
    my ($self) = @_;
    return $self->{'wrapX'};
}

sub wrapsY {
    my ($self) = @_;
    return $self->{'wrapY'};
}

sub set_wrapX {
    my ($self, $value) = @_;
    
    $self->{'wrapX'} = $value;
    foreach my $layer ($self->get_layers()) {
        $layer->set_wrapX($value);
    }
}

sub set_wrapY {
    my ($self, $value) = @_;
    
    $self->{'wrapY'} = $value;
    foreach my $layer ($self->get_layers()) {
        $layer->set_wrapY($value);
    }
}

sub get_width {
    my ($self) = @_;
    return $self->{'width'};
}

sub get_height {
    my ($self) = @_;
    return $self->{'height'};
}

sub expand_dim {
    my ($self, $width, $height) = @_;
    $self->{'width'} = $width;
    $self->{'height'} = $height;
}

sub crop {
    my ($self, $left, $bottom, $right, $top) = @_;
    
    foreach my $layer ($self->get_layers()) {
        if ($layer->check_croppable($left, $bottom, $right, $top)) {
            $layer->crop($left, $bottom, $right, $top);
            $layer->move(-$left, -$bottom) if ($left > 0) or ($bottom > 0);
        }
    }
    
    $self->{'width'} = $right - $left + 1;
    $self->{'height'} = $top - $bottom + 1;
}

sub set_layer {
    my ($self, $name, $new_layer) = @_;
    $self->{'layers'}{$name} = $new_layer;
}

sub layer_exists {
    my ($self, $name) = @_;
    return 1 if exists $self->{'layers'}{$name};
    return 0;
}

sub rename {
    my ($self, $new_name) = @_;
    $self->{'name'} = $new_name;
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
    my $group_name = $self->get_name();
    
    $layer->set_membership($self);
    $layer->set_wrapX($self->{'wrapX'});
    $layer->set_wrapY($self->{'wrapY'});
    
    my %ret = ('error_msg' => '');
    
    if (exists $self->{'layers'}{$layer_name}) {
        $self->{'layers'}{$layer_name} = $layer;
        
        $ret{'error'} = 1;
        $ret{'error_msg'} = "layer named '$layer_name' already exists in group '$group_name'... overwriting";
    }
    else {
        $self->{'max_priority'} ++;
        $self->{'layers'}{$layer_name} = $layer;
        $self->{'priority'}{$layer_name} = $self->{'max_priority'};
    }
    
    if (($layer->get_width() > $self->get_width()) or ($layer->get_height() > $self->get_height())) {
        if ($layer->get_width() > $self->get_width()) {
            $self->{'width'} = $layer->get_width();
        }
        
        if ($layer->get_height() > $self->get_height()) {
            $self->{'height'} = $layer->get_height();
        }
        
        $ret{'error'} = 1;
        $ret{'error_msg'} .= " and " if $ret{'error_msg'} =~ /\w/;
        $ret{'error_msg'} .= "the addition of layer named '$layer_name' to group '$group_name' has stretched its size.";
        
    }
   
    $ret{'error_msg'} .= '.';
    return \%ret;
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
        next if $name eq $layer_name;
        if ($self->{'priority'}{$name} >= $new_priority) {
            $self->{'priority'}{$name} = $self->{'priority'}{$name} + 1;
            if (($self->{'priority'}{$name}) > $self->{'max_priority'}) {
                $self->{'max_priority'} = $self->{'priority'}{$name};
            }
        }        
    }
   
    $self->{'priority'}{$layer_name} = $new_priority;
    if (($self->{'priority'}{$layer_name}) > $self->{'max_priority'}) {
        $self->{'max_priority'} = $self->{'priority'}{$layer_name};
    }
    
    # readjust so that '0' is always the top priority
    my $min = 100000;
    foreach my $name (keys %{ $self->{'layers'} }) {
        $min = $self->{'priority'}{$name} if $self->{'priority'}{$name} < $min;
    }
    
    if ($min > 0) {
        $self->{'max_priority'} -= $min;
        foreach my $name (keys %{ $self->{'layers'} }) {
            $self->{'priority'}{$name} -= $min;
        }
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
   
    my $merged = $layer1->merge_with_layer($layer2);
    $self->{'layers'}{$layer1_name} = $merged;
   
    return 1;
}
 
sub merge_all {
    my ($self, $rename_final_to_match) = @_;
   
    while (1) {
        my @remaining_layers = $self->get_layer_names();
        last if @remaining_layers == 1;
       
        $self->merge_two_and_replace($remaining_layers[0], $remaining_layers[1]);
    }
    
    my @remaining_layers = $self->get_layer_names();
    my $remnant = $remaining_layers[0];
    
    # fill in the background so the final result has the correct size
    my $background = Civ4MapCad::Object::Layer->new_default('__background', $self->get_width(), $self->get_height());
    $self->{'layers'}{$remnant} = $self->{'layers'}{$remnant}->merge_with_layer($background);
    $self->{'layers'}{$remnant}->rename($self->get_name()) if $rename_final_to_match;
    
    # cleanup priority list
    $self->{'priority'}{$remnant} = 0;
    $self->{'max_priority'} = 0;
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
    my ($self, $mask, $clear_selected) = @_;
    
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
        
        my $start_layer = $self->{'layers'}{$layer_name}->select_with_mask($mask, $offsetX, $offsetY, $clear_selected);
        $start_layer->set_player_from_layer($owner, $self->{'layers'}{$layer_name});
        $start_layer->rename("start" . $owner);
        $start_layer->strip_hidden_strategic();
        $start_layer->strip_victories();
        $start_layer->set_difficulty($main::config{'difficulty'});
        
        my $p = $self->{'priority'}{$layer_name};
        $self->add_layer($start_layer);
        #$self->set_layer_priority($start_layer->get_name(), $start_layer, $p);
    }
    
    return 1;
}

sub export {
    my ($self, $output_dir) = @_;

    my $group_name = $self->get_name();
    $group_name =~ s/\$//;
    
    my @layers = $self->get_layers();
    $main::config{'state'}->buffer_bar();
    
    print "\n";
    foreach my $layer (@layers) {
        my $layer_name = $layer->get_name();
        my $path = $output_dir . "/" . $self->get_name() . "." . $layer_name . ".CivBeyondSwordWBSave";
        
        my $strip = 1;
        if ($self->get_name() eq $layer->get_name()) {
            $strip = 0;
            $path = $output_dir . "/" . $group_name . ".CivBeyondSwordWBSave" ;
        }
        
        $layer->reduce_players();
        $layer->add_dummy_start() if $layer->num_players() == 1;
        $layer->export_layer($path);
        
        $main::config{'state'}->report_message("Exported layer $layer_name.");
    }
    
    print "\n";
    return 1;
}

1;
