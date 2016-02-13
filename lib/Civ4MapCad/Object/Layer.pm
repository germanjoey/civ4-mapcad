package Civ4MapCad::Object::Layer;

use strict;
use warnings;

use List::Util qw(min max);

use Civ4MapCad::Map;
use Civ4MapCad::Object::Mask;
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
    
    my $blessed = bless $obj, $class;
    $main::state->set_ref_id($blessed);
    return $blessed;
}

sub new_from_import {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($name, $filename) = @_;
    my $map = Civ4MapCad::Map->new();
    my $ret = $map->import_map($filename);
    if ($ret ne '') {
        return $ret;
    }
    
    my $obj = {
        'ref_id' => $main::state->next_ref_id(),
        'd' => 0,
        'name' => $name,
        'map' => $map,
        'offsetX' => 0,
        'offsetY' => 0,
    };
    
    my $blessed = bless $obj, $class;
    $main::state->set_ref_id($blessed);
    return $blessed;
}

sub destroy_layer {
    my ($self) = @_;
    
    my $id = $self->{'ref_id'};
    undef %{ $main::state->{'ref_table'}{$id}{'map'} };
    delete $main::state->{'ref_table'}{$id}{'map'};
    delete $main::state->{'ref_table'}{$id}{'member_of'} if exists $self->{'ref_table'}{$id}{'member_of'};
   
    undef %{ $main::state->{'ref_table'}{$id} };
    delete $main::state->{'ref_table'}{$id};
}

sub get_name {
    my ($self) = @_;
    return $self->{'name'};
}

sub get_full_name {
    my ($self) = @_;
    return '$' . $self->get_group()->get_name() . '.' . $self->{'name'};
}

sub rename {
    my ($self, $new_name) = @_;
    $self->{'name'} = $new_name;
}

sub set_turn0 {
    my ($self) = @_;
    $self->{'map'}->set_turn0();
}

sub get_group {
    my ($self) = @_;
    return $self->{'member_of'};
}

sub set_membership {
    my ($self, $group) = @_;
    $self->{'member_of'} = $group;
}

sub get_speed {
    my ($self) = @_;
    return $self->{'map'}->get_speed();
}

sub set_speed {
    my ($self, $speed) = @_;
    $self->{'map'}->set_speed($speed);
}

sub get_size {
    my ($self) = @_;
    return $self->{'map'}->get_size();
}

sub set_size {
    my ($self, $size) = @_;
    $self->{'map'}->set_size($size);
}

sub get_era {
    my ($self) = @_;
    return $self->{'map'}->get_era();
}

sub set_era {
    my ($self, $era) = @_;
    $self->{'map'}->set_era($era);
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

sub get_offsetX {
    my ($self) = @_;
    return $self->{'offsetX'};
}

sub get_offsetY {
    my ($self) = @_;
    return $self->{'offsetY'};
}

sub get_width {
    my ($self) = @_;
    return $self->{'map'}->info('grid width');
}

sub get_height {
    my ($self) = @_;
    return $self->{'map'}->info('grid height');
}

sub move_to {
    my ($self, $toX, $toY) = @_;
    $self->{'offsetX'} = $toX;
    $self->{'offsetY'} = $toY;
}

sub move_by {
    my ($self, $byX, $byY) = @_;
    $self->{'offsetX'} += $byX;
    $self->{'offsetY'} += $byY;
}

sub fill_tile {
    my ($self, $x, $y) = @_;
    $self->{'map'}->fill_tile($x, $y);
}

sub delete_tile {
    my ($self, $x, $y) = @_;
    $self->{'map'}->delete_tile($x, $y);
}

sub expand_dim {
    my ($self, $new_width, $new_height) = @_;
    
    my $width = max($new_width, $self->get_width());
    my $height = max($new_height, $self->get_height());
    
    $self->{'map'}->expand_dim($width, $height);
}

sub translate_merge_coords {
    my ($self, $x, $y, $oX, $oY) = @_;
    
    # factor in the offset
    my $sx = $x + $oX;
    my $sy = $y + $oY;
    
    my $gwidth = $self->get_group()->get_width();
    my $gheight = $self->get_group()->get_height();

    # if we don't wrap, check to see if we're out of bounds. we return -1,-1 in that case
    return (-1, -1) if (($sx >= $gwidth) or ($sx < 0)) and (!$self->wrapsX());
    return (-1, -1) if (($sy >= $gheight) or ($sy < 0)) and (!$self->wrapsY());
    
    # translate wrap
    my $tx = ($sx >= $gwidth) ? ($sx - $gwidth) : (($sx < 0) ? ($sx + $gwidth) : $sx);
    my $ty = ($sy >= $gheight) ? ($sy - $gheight) : (($sy < 0) ? ($sy + $gheight) : $sy);
    
    return ($tx, $ty);
}

# TODO: merge signs
# returns a new Layer object - whether the map gets overwritten or not is up to the container object's methods
# self has the more important priority here
sub merge_with_layer {
    my ($self, $othr) = @_;
    
    # first make a copy of the layer so we keep all our map settings
    my $copy = deepcopy($self);    
    
    my $new_width = $self->get_group()->get_width();
    my $new_height = $self->get_group()->get_height();
    
    $copy->expand_dim($new_width, $new_height);
    $copy->{'map'}->clear_map();
    
    my $group_width = $self->get_group()->get_width();
    my $group_height = $self->get_group()->get_height();
    
    # first we do the tiles in the other layer
    for my $x (0 .. $othr->get_width()-1) {
        for my $y (0 .. $othr->get_height()-1) {
            my ($tx, $ty) = $copy->translate_merge_coords($x, $y, $othr->{'offsetX'}, $othr->{'offsetY'});
            next if ($tx < 0) or ($tx >= $group_width);
            next if ($ty < 0) or ($ty >= $group_height);
            
            $copy->{'map'}{'Tiles'}[$tx][$ty] = deepcopy($othr->{'map'}{'Tiles'}[$x][$y]);
            $copy->{'map'}{'Tiles'}[$tx][$ty]->set('x', $tx);
            $copy->{'map'}{'Tiles'}[$tx][$ty]->set('y', $ty);
        }
    }
    
    # then we write on top of them with this layer
    for my $x (0 .. $self->get_width()-1) {
        for my $y (0 .. $self->get_height()-1) {
            next if $self->{'map'}{'Tiles'}[$x][$y]->is_blank();
            my ($tx, $ty) = $copy->translate_merge_coords($x, $y, $self->{'offsetX'}, $self->{'offsetY'});
            next if ($tx < 0) or ($tx >= $group_width);
            next if ($ty < 0) or ($ty >= $group_height);
            
            $copy->{'map'}{'Tiles'}[$tx][$ty] = deepcopy($self->{'map'}{'Tiles'}[$x][$y]);
            $copy->{'map'}{'Tiles'}[$tx][$ty]->set('x', $tx);
            $copy->{'map'}{'Tiles'}[$tx][$ty]->set('y', $ty);
        }
    }
    
    $copy->{'Signs'} = [];
    
    # finally we do the signs
    foreach my $sign (@{ $othr->{'map'}{'Signs'} }) {
        my ($tx, $ty) = $copy->translate_merge_coords($sign->{'plotX'}, $sign->{'plotY'}, $othr->{'offsetX'}, $othr->{'offsetY'});
        next if ($tx < 0) or ($tx >= $group_width);
        next if ($ty < 0) or ($ty >= $group_height);
        
        $copy->{'map'}->add_sign_to_coord($tx, $ty, $sign->get('caption'));
    }    
    
    foreach my $sign (@{ $self->{'map'}{'Signs'} }) {
        my ($tx, $ty) = $copy->translate_merge_coords($sign->{'plotX'}, $sign->{'plotY'}, $self->{'offsetX'}, $self->{'offsetY'});
        next if ($tx < 0) or ($tx >= $group_width);
        next if ($ty < 0) or ($ty >= $group_height);
        $copy->{'map'}->add_sign_to_coord($tx, $ty, $sign->get('caption'));
    }    
    
    $copy->{'offsetX'} = 0;
    $copy->{'offsetY'} = 0;
    
    return $copy;
}

sub export_layer {
    my ($self, $filename) = @_;
    $self->fix_coast();
    $self->{'map'}->export_map($filename);
}

sub set_wrapX {
    my ($self, $value) = @_;
    $self->{'map'}->set_wrapX($value);
}

sub set_wrapY {
    my ($self, $value) = @_;
    $self->{'map'}->set_wrapY($value);
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

sub set_tile {
    my ($self, $x, $y, $terrain) = @_;
    $self->{'map'}{'Tiles'}[$x][$y]->set_tile($terrain);
}

sub clear_tile {
    my ($self, $x, $y, $terrain) = @_;
    $self->{'map'}{'Tiles'}[$x][$y]->default($x, $y);
}

sub update_tile {
    my ($self, $x, $y, $terrain, $allowed) = @_;
    $self->{'map'}{'Tiles'}[$x][$y]->update_tile($terrain, $allowed);
}

sub apply_mask {
    my ($self, $mask, $weight, $mask_offsetX, $mask_offsetY, $overwrite, $allowed, $clear_matched) = @_;
    
    for my $x (0 .. $mask->get_width()-1) {
        for my $y (0 .. $mask->get_height()-1) {
            my ($tx, $ty) = $self->translate_mask_coords($x, $y, $mask_offsetX, $mask_offsetY);
            next if ($tx < 0) or ($tx >= $self->get_width());
            next if ($ty < 0) or ($ty >= $self->get_height());
        
            my ($terrain_name, $terrain) = $weight->evaluate($mask->{'canvas'}[$x][$y]);
            next unless defined $terrain;
            
            if ($overwrite) {
                $self->set_tile($tx, $ty, $terrain);
            }
            elsif ($clear_matched) {
                $self->clear_tile($tx, $ty);
            }
            else {
                $self->update_tile($tx, $ty, $terrain, $allowed);
            }
        }
    }
    
    $weight->deflate();
}

sub apply_weight {
    my ($self, $weight, $exact, $post_match_threshold) = @_;
    
    my $mask = Civ4MapCad::Object::Mask->new_blank($self->get_width(), $self->get_height());
    
    for my $x (0 .. $self->get_width()-1) {
        for my $y (0 .. $self->get_height()-1) {
            my $tile = $self->{'map'}{'Tiles'}[$x][$y];
            
            my ($value) = $weight->evaluate_inverse($tile, $exact);
            
            $mask->{'canvas'}[$x][$y] = (defined $value) ? max($post_match_threshold, $value) : 0.0;
            
        }
    }
    
    $weight->deflate();
    return $mask;
}

sub select_with_mask {
    my ($self, $mask, $mask_offsetX, $mask_offsetY, $clear_selected) = @_;
    
    my $sel_name = $self->get_name() . "_" . $self->{'d'};
    $self->{'d'} ++;
    
    my $selection = Civ4MapCad::Object::Layer->new_default($sel_name, $mask->get_width(), $mask->get_height());
    
    for my $x (0 .. $mask->get_width()-1) {
        for my $y (0 .. $mask->get_height()-1) {
            if ($mask->{'canvas'}[$x][$y] > 0) { # TODO: add variable threshold
                my ($tx, $ty) = $self->translate_mask_coords($x, $y, $mask_offsetX, $mask_offsetY);
                
                next if ($tx < 0) or ($tx >= $self->get_width());
                next if ($ty < 0) or ($ty >= $self->get_height());
            
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
    
    my $starts = $selection->find_starts();
    foreach my $start (@$starts) {
        my ($x,$y,$player) = @$start;
        $selection->set_player_from_layer($player, $self);
    }
    
    $selection->rename($self->get_name() . '_selection');
    $selection->set_wrapX($self->wrapsX());
    $selection->set_wrapY($self->wrapsY());
    $selection->set_speed($self->get_speed());
    $selection->set_size($self->get_size());
    $selection->set_era($self->get_era());
    
    $selection->move_to($mask_offsetX, $mask_offsetY);
    return $selection;
}

sub set_difficulty {
    my ($self, $level) = @_;
    return $self->{'map'}->set_difficulty($level);
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
            $starts_found{$owner} = [[$x, $y]];
        }
    }
    
    my @duplicates = grep { @{$starts_found{$_}} > 1 } (keys %starts_found);
    foreach my $duplicate_owner_id (@duplicates) {
        my $dups = $starts_found{$duplicate_owner_id};
        my $assigned_start = shift @$dups; # this first one doesn't get re-assigned
        
        while (1) {
            last if @$dups == 0;
            my $start_to_reassign = shift @$dups;
            my ($x, $y) = @$start_to_reassign;
            
            my $new_owner_id = _get_next_open_start_id(\%starts_found);
            $starts_found{$new_owner_id} = 1;
            $self->reassign_start_at($x, $y, $duplicate_owner_id, $new_owner_id);
        }
    }
    
    return 1;
}

sub reassign_start_at {
    my ($self, $x, $y, $original_owner_id, $new_owner_id) = @_;
    $self->{'map'}->reassign_start_at($x, $y, $original_owner_id, $new_owner_id);
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

sub check_croppable {
    my ($self, $left, $bottom, $right, $top) = @_;
    
    my $layer_left = $self->{'offsetX'};
    my $layer_right = $self->{'offsetX'} + $self->get_width() - 1;
    my $layer_bottom = $self->{'offsetY'};
    my $layer_top = $self->{'offsetY'} + $self->get_height() - 1;
    
    my $cropped_width = min($right, $layer_right) - max($left, $layer_left);
    my $cropped_height = min($top, $layer_top) - max($bottom, $layer_bottom);

    return -1 if ($cropped_height <= 0) or ($cropped_width <= 0);
    
    return 1 if ($layer_left < $left) and ($layer_right > $left);
    return 1 if ($layer_right > $left) and ($layer_right > $right);
    return 1 if ($layer_bottom < $bottom) and ($layer_top > $bottom);
    return 1 if ($layer_top > $bottom) and ($layer_top > $top);
    
    return 0;
}

sub crop {
    my ($self, $left, $bottom, $right, $top) = @_;
    
    my $actual_left = max(0, $left - $self->{'offsetX'});
    my $actual_bottom = max(0, $bottom - $self->{'offsetY'});
    my $actual_right = min($self->get_width() - 1, $right - $self->{'offsetX'});
    my $actual_top = min($self->get_height() - 1, $top - $self->{'offsetY'});
    
    $self->{'map'}->crop($actual_left, $actual_bottom, $actual_right, $actual_top);
    return 1;
}

sub get_player_data {
    my ($self, $owner_id) = @_;
    return $self->{'map'}->get_player_data($owner_id);
}

sub set_player_from_other {
    my ($self, $owner_id, $player, $team) = @_;
    $self->{'map'}->set_player_from_other($owner_id, $player, $team);
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
    my ($self, $new_max) = @_;
    return $self->{'map'}->set_max_num_players($new_max);
}

sub fliplr {
    my ($self) = @_;
    $self->{'map'}->fliplr();
}

sub fliptb {
    my ($self) = @_;
    $self->{'map'}->fliptb();
}

sub set_player_from_civdata {
    my ($self, $owner, $civ_data) = @_;
    $self->{'map'}->set_player_from_civdata($owner, $civ_data);
}

sub set_player_leader {
    my ($self, $owner, $leader_data) = @_;
    $self->{'map'}->set_player_leader($owner, $leader_data);
}

sub set_player_color {
    my ($self, $owner, $color) = @_;
    $self->{'map'}->set_player_color($owner, $color);
}

sub set_player_name {
    my ($self, $owner, $name) = @_;
    $self->{'map'}->set_player_name($owner, $name);
}

sub get_tile {
    my ($self, $x, $y) = @_;
    return $self->{'map'}->get_tile($x, $y);
}

sub follow_land_tiles {
    my ($self, $start_tile, $inc_ocean_res) = @_;
    
    my $process = sub {
        my ($mark_as_checked, $tile) = @_;
        $mark_as_checked->($tile->{'x'}, $tile->{'y'}, $tile);
        return 1 if $tile->is_land();
        return 0;
    };
    
    my ($land, $water) = $self->follow_tiles($start_tile, $process);
    
    if ($inc_ocean_res) {
    
        my %ocean_res;
        my @directions = ('1 1', '0 1', '-1 1', '1 0', '-1 0', '1 -1', '0 -1', '-1 -1');
        
        # now we look at every damn coast tile we found, and check to see if any of its surrounding tiles are ocean+resource
        foreach my $coast_tile_coord (keys %$water) {
            my ($x, $y) = split '/', $coast_tile_coord;
        
            foreach my $direction (@directions) {
                my ($xd, $yd) = split ' ', $direction;
                my $tx = $x + $xd;
                my $ty = $y + $yd;
                
                my $tile = $self->get_tile($tx, $ty);
                next unless defined $tile;
                
                $ocean_res{"$tx/$ty"} = $tile if ($tile->has_bonus() or $tile->has_feature()) and ($tile->get('TerrainType') eq 'TERRAIN_OCEAN');
            };
        }
        
        # now that nonsense is over, add the found resources to the original water collection
        while ( my($k,$v) = each %ocean_res) {
            $water->{$k} = $v;
        }
    }
    
    return ($land, $water);
}

sub follow_water_tiles {
    my ($self, $start_tile, $only_coast) = @_;
    
    my $process = sub {
        my ($mark_as_checked, $tile) = @_;
        $mark_as_checked->($tile->get('x'), $tile->get('y'), $tile);
        return 1 if $tile->is_water();
        return 0;
    };
    
    my ($land, $water) = $self->follow_tiles($start_tile, $process);
    
    if ($only_coast) {
        while ( my($k,$v) = each %$water) {
            if ($v->get('TerrainType') eq 'TERRAIN_OCEAN') {
                delete $water->{$k};
            }
        }
    }
    
    return ($land, $water);
}

sub follow_tiles {
    my ($self, $start_tile, $process) = @_;
    
    my (%land, %water, %nonexistant);
    
    my $is_already_checked = sub {
        my ($x, $y) = @_;
        return 1 if exists($land{"$x/$y"}) or exists($water{"$x/$y"}) or exists($nonexistant{"$x/$y"});
        return 0;
    };

    my $mark_as_checked = sub {
        my ($x, $y, $tile) = @_;
        if (! defined($tile)) {
            $nonexistant{"$x/$y"} = $tile;
        }
        elsif ($tile->is_land()) {
            $land{"$x/$y"} = $tile;
        }
        else {
            $water{"$x/$y"} = $tile;
        }
    };
    
    $self->{'map'}->region_search($start_tile, $is_already_checked, $mark_as_checked, $process);
    return (\%land, \%water);
}

sub rotate {
    my ($self, $angle, $it, $autocrop) = @_;
    
    return (0,0) if ($angle % 360) == 0;
    
    my $group_width = $self->get_group()->get_width();
    my $group_height = $self->get_group()->get_height();
    
    my ($new_width, $new_height, $move_x, $move_y, $result_angle1, $result_angle2) = $self->{'map'}->rotate($angle, $it, $autocrop);
        
    # expand the group if the result layer is bigger than the group was originally
    if (($group_width < $new_width) or ($group_height < $new_height)) {
        $self->get_group()->expand_dim(max($new_width, $group_width), max($new_height, $group_height));
    }
        
    if ($autocrop == 0) {
        # now correctly position the rotated layer
        $move_x = -$move_x;
        $move_y = -$move_y;
        
        $group_width = $self->get_group()->get_width();
        $group_height = $self->get_group()->get_height();
        
        if ($move_x >= $group_width) {
            while ($move_x >= $group_width) {
                $move_x -= $group_width;
            }
        }
        elsif ((-$move_x) >= $group_width) {
            while ((-$move_x) >= $group_width) {
                $move_x += $group_width;
            }
        }
        
        if ($move_y >= $group_height) {
            while ($move_y >= $group_height) {
                $move_y -= $group_height;
            }
        }
        elsif ((-$move_y) >= $group_height) {
            while ((-$move_y) >= $group_height) {
                $move_y += $group_height;
            }
        }
        
        $self->move_by($move_x, $move_y);
    }
    
    return ($move_x, $move_y, $result_angle1, $result_angle2);
}


sub fix_reveal {
    my ($self) = @_;

    $self->{'map'}->fix_reveal();
}


sub fix_map {
    my ($self) = @_;

    $self->{'map'}->fix_map();
}

sub add_sign {
    my ($self, $x, $y, $caption) = @_;
    $self->{'map'}->add_sign_to_coord($x, $y, $caption);
}

1;