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
        'd' => 0,
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
    my $map = Civ4MapCad::Map->new();
    $map->import_map($filename);
    
    my $obj = {
        'd' => 0,
        'name' => $name,
        'map' => $map,
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
# TODO: the container is what should actually do the copy, not this method
sub merge_with_layer {
    my ($self, $othr) = @_;
    
    my $copy = deepcopy($self);
    
    # next, calculate new dimensions
    my $left = min($copy->{'offsetX'}, $othr->{'offsetX'});
    my $right = max($copy->{'offsetX'} + $copy->get_width(), $othr->{'offsetX'} + $othr->get_width()); 
    my $bottom = min($copy->{'offsetY'}, $othr->{'offsetY'});
    my $top = max($copy->{'offsetY'} + $copy->get_height(), $othr->{'offsetY'} + $othr->get_height());
    
    my $width = $right - $left;
    my $height = $top - $bottom;
    
    $copy->{'map'}->expand_dim($width, $height);
    $copy->{'map'}->clear_map();
    $copy->{'map'}->overwrite_tiles($self->{'map'}, $self->{'offsetX'}, $self->{'offsetY'});
    $copy->{'map'}->overwrite_tiles($othr->{'map'}, $othr->{'offsetX'}, $othr->{'offsetY'});
    
    $copy->{'offsetX'} = $left;
    $copy->{'offsetY'} = $bottom;
    
    return $copy;
}

sub export_layer {
    my ($self, $filename) = @_;
    $self->fix_coast();
    $self->{'map'}->export_map($filename);
}

sub wrapsX {
    my ($self) = @_;
    return $self->{'map'}->wrapsX();
}

sub wrapsY {
    my ($self) = @_;
    return $self->{'map'}->wrapsY();
}

sub translate_mask_coords {
    my ($self, $x, $y, $oX, $oY) = @_;
    
    # factor in the offset
    my $sx = $x + $oX;
    my $sy = $y + $oY;
    
    my $mwidth = $self->get_width();
    my $mheight = $self->get_height();

    # if we don't wrap, check to see if we're out of bounds. we return -1,-1 in that case
    return (-1, -1) if (($sx >= $mwidth) or ($sx < 0)) and (!$self->wrapsX());
    return (-1, -1) if (($sy >= $mheight) or ($sy < 0)) and (!$self->wrapsY());
    
    # translate wrap
    my $tx = ($sx >= $mwidth) ? ($sx - $mwidth) : (($sx < 0) ? ($sx + $mwidth) : $sx);
    my $ty = ($sy >= $mheight) ? ($sy - $mheight) : (($sy < 0) ? ($sy + $mheight) : $sy);
    
    return ($tx, $ty);
}

sub apply_mask {
    my ($self, $mask, $weight, $mask_offsetX, $mask_offsetY, $overwrite) = @_;
    
    for my $x (0 .. $mask->get_width()-1) {
        for my $y (0 .. $mask->get_height()-1) {
            my ($tx, $ty) = $self->translate_mask_coords($x, $y, $mask_offsetX, $mask_offsetY);
            next if ($tx < 0) or ($tx >= $self->get_width());
            next if ($ty < 0) or ($ty >= $self->get_width());
        
            my $terrain = $weight->evaluate($mask->{'canvas'}[$x][$y]);
            
            if ($overwrite) {
                $self->{'map'}{'Tiles'}[$tx][$ty]->set_tile($terrain);
            }
            else {
                $self->{'map'}{'Tiles'}[$tx][$ty]->update_tile($terrain);
            }
        }
    }
    
    $weight->deflate();
}

sub select_with_mask {
    my ($self, $mask, $mask_offsetX, $mask_offsetY, $clear_selected) = @_;
    
    my $sel_name = $self->get_name() . "_" . $self->{'d'};
    $self->{'d'} ++;
    
    my $selection = Civ4MapCad::Object::Layer->new_default($sel_name, $mask->get_width(), $mask->get_height());
    
    for my $x (0 .. $mask->get_height()-1) {
        for my $y (0 .. $mask->get_width()-1) {
            if ($mask->{'canvas'}[$x][$y] > 0) { # TODO: add variable threshold
                my ($tx, $ty) = $self->translate_mask_coords($x, $y, $mask_offsetX, $mask_offsetY);
                
                next if ($tx < 0) or ($tx >= $self->get_width());
                next if ($ty < 0) or ($ty >= $self->get_width());
            
                $selection->{'map'}{'Tiles'}[$x][$y] = deepcopy($self->{'map'}{'Tiles'}[$tx][$ty]);
                $selection->{'map'}{'Tiles'}[$x][$y]->set('x', $x);
                $selection->{'map'}{'Tiles'}[$x][$y]->set('y', $y);
                
                if ($clear_selected) {
                    $self->{'map'}{'Tiles'}[$tx][$ty]->clear();
                    $self->{'map'}{'Tiles'}[$tx][$ty]->default($tx, $ty);
                }
            }
        }
    }
    
    $selection->move($mask_offsetX, $mask_offsetY);
    
    return $selection;
}

sub set_difficulty {
    my ($self, $level) = @_;
    $self->{'map'}->set_difficulty($level);
}

sub set_player_from_layer {
    my ($self, $player, $other_layer) = @_;
    
    $self->{'map'}{'Players'}[$player] = deepcopy($other_layer->{'map'}{'Players'}[$player]);
    $self->{'map'}{'Teams'}{$player} = deepcopy($other_layer->{'map'}{'Teams'}{$player});
}

sub normalize_starts {
    my ($self) = @_;

    my %starts_found;
    my $all_starts = $self->find_starts();
    
    foreach my $start (@$all_starts) {
        my ($x, $y, $owner) = @$start;
        
        if (exists $starts_found{$owner}) {
            push @{ $starts_found{$owner} }, [$x, $y];
        }
        else {
            $starts_found{$owner} = [$x, $y];
        }
    }
    
    foreach my $duplicate_start (grep {$_ > 1 } (keys %starts_found)) {
        my @dups = $starts_found{$duplicate_start};
        my $assigned = shift @dups;
        
        while (1) {
            last if @dups == 0;
            my $assigned = shift @dups;
            my ($x, $y) = @$assigned;
            
            my $new_id = _get_next_open_start_id(\%starts_found);
            $starts_found{$new_id} = 1;
            $self->{'map'}->reassign_start_at($x, $y, $duplicate_start, $new_id);
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
    return $self->{'map'}->find_starts();
}

sub reassign_start {
    my ($self, $old, $new) = @_;
    $self->{'map'}->reassign_start($old, $new);
}

sub strip_all_units {
    my ($self) = @_;
    $self->{'map'}->strip_all_units();
}

sub strip_nonsettlers {
    my ($self) = @_;
    $self->{'map'}->strip_nonsettlers();
}

sub add_scouts_to_settlers {
    my ($self) = @_;
    $self->{'map'}->add_scouts_to_settlers();
}

sub reduce_players {
    my ($self) = @_;
    $self->{'map'}->reduce_players();
}

sub num_players {
    my ($self) = @_;
    return $self->{'map'}->num_players();
}

sub add_dummy_start {
    my ($self) = @_;
    return $self->{'map'}->add_dummy_start();
}

sub fix_coast {
    my ($self) = @_;
    return $self->{'map'}->fix_coast();
}

sub strip_hidden_strategic {
    my ($self) = @_;
    return $self->{'map'}->strip_hidden_strategic();
}

sub strip_victories {
    my ($self) = @_;
    return $self->{'map'}->strip_victories();
}

sub set_max_num_players {
    my ($self) = @_;
    return $self->{'map'}->set_max_num_players();
}


sub get_surrounding {
    my ($self, $x, $y) = @_;
    
    my $width = $self->get_width();
    my $height = $self->get_height();
    
    # setup the standard surrounding coordinates
    my %coords = (
        '-1' => {
            '-1' => [$x-1, $y-1],
            '0' => [$x-1, $y],
            '+1' => [$x-1, $y+1],
        },
        '0' => {
            '-1' => [$x, $y-1],
            '+1' => [$x, $y+1],
        },
        '+1' => {
            '-1' => [$x+-1, $y-1],
            '0' => [$x+1, $y],
            '+1' => [$x+1, $y+1],
        }
    );
    my $xp1 = $x + 1;
    my $xm1 = $x - 1;
    
    # wrap X, or filter out these coords if we don't wrap X
    if ($x == 0) {
        $coords{'-1'}{'-1'}[0] = $width-1;
        $coords{'-1'}{'0'}[0] = $width-1;
        $coords{'-1'}{'+1'}[0] = $width-1;
        delete $coords{'-1'} unless $self->wrapsX();
    }
    elsif ($x == $width-1) {
        $coords{'+1'}{'-1'}[0] = 0;
        $coords{'+1'}{'0'}[0] = 0;
        $coords{'+1'}{'+1'}[0] = 0;
        delete $coords{'-1'} unless $self->wrapsX();
    }
    
    # wrap Y, or filter out these coords if we don't wrap Y
    if ($y == 0) {
        $coords{'-1'}{'-1'}[0] = $height-1;
        $coords{'0'}{'-1'}[0] = $height-1;
        $coords{'+1'}{'-1'}[0] = $height-1;
        
        delete $coords{'-1'}{'-1'} if (exists $coords{'-1'}) and (!$self->wrapsY());
        delete $coords{'0'}{'-1'} if (exists $coords{'0'}) and (!$self->wrapsY());
        delete $coords{'+1'}{'-1'} if (exists $coords{'+1'}) and (!$self->wrapsY());
    }
    elsif ($y == $height-1) {
        $coords{'-1'}{'-1'}[0] = 0;
        $coords{'0'}{'-1'}[0] = 0;
        $coords{'+1'}{'-1'}[0] = 0;
        
        delete $coords{'-1'}{'-1'} if (exists $coords{'-1'}) and (!$self->wrapsY());
        delete $coords{'0'}{'-1'} if (exists $coords{'0'}) and (!$self->wrapsY());
        delete $coords{'+1'}{'-1'} if (exists $coords{'+1'}) and (!$self->wrapsY());
    }
    
    # now, just gather what we have left
    my @surrounding;
    my $tiles = $self->{'map'}{'Tiles'};
    foreach my $xd (keys %coords) {
        foreach my $yd (keys %{ $coords{$xd} }) {
            my ($x, $y) = @{ $coords{$xd}{$yd} };
            push @surrounding, $tiles->[$x][$y];
        }
    }
    
    return \@surrounding;
}

1;