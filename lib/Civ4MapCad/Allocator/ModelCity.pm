package Civ4MapCad::Allocator::ModelCity;

use strict;
use warnings;

use List::Util qw(min max);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($player, $center, $turn, $order, $initial_delay) = @_;
    
    my $obj = bless {
        'player' => $player,
        'center' => $center,
        'settlement_order' => $order,
        'settling_turn' => ($turn + $initial_delay),
        'current_turn' => $turn,
        'last_chop' => ($turn + $initial_delay),
        'last_whip' => ($turn + $initial_delay), 
        'is_capital' => 0,
        
        'available_trees' => int($center->{'bfc'}->count_trees()/2 + 0.5),
        'initial_delay' => $initial_delay,
        'max_fpt' => -1,
        'growth_delay' => 0,
        'growth_target' => 1,
        'final_target' => 1,
        'whip_threshold' => 0,
        'food_bin' => 0,
        'hammer_bin' => 0,
        'current_fpt' => 0,
        'current_hpt' => 0,
        'current_size' => 1,
        'current_status' => 'growth',
        'ready_to_build' => 0,
        'stop_settling' => 0,
        'times_grown' => 0,
        'times_whipped' => 0,
        
        'hammers_for_granary' => 0,
        'has_granary' => 0,
        'granary_enabled' => 0,
        
        'turns_for_expansion' => 0, # border expansion
        'borders_expanded' => 0,
    }, $class;
    
    $obj->initialize();
    
    return $obj;
}

sub get_center {
    my ($self) = @_;
    return $self->{'center'}
}

sub get_settlment_turn {
    my ($self) = @_;
    return $self->{'settling_turn'};
}

sub can_whip {
    my ($self) = @_;
    return 0 if $self->{'max_fpt'} < 3;
    return ($self->{'current_size'} > $self->{'whip_threshold'}) ? 1 : 0;
}

sub ready_to_build {
    my ($self) = @_;
    return $self->{'ready_to_build'};
}

# start to build
sub set_queue {
    my ($self, $queue) = @_;
    $self->{'current_status'} = $queue;
    $self->choose_tiles();
    $self->{'ready_to_build'} = 0;
}

sub has_resources {
    my ($self, @resources) = @_;
    
    if ($self->{'borders_expanded'} == 0) {
        $self->{'center'}{'bfc'}->has_resource_1st_ring(@resources);
    }
    else {
        $self->{'center'}{'bfc'}->has_resource_any_ring(@resources);
    }
}

sub stop_settling {
    my ($self) = @_;
    $self->{'stop_settling'} = 1;
}

# tiles at this point are just [food/hammer/commerce/pre-expanded/bonus_name]
# order tiles, determine time to border expansion, the delay before the city 
# starts pumping, and the delay before its ratio drops
sub initialize {
    my ($self) = @_;
    
    my $extra_help_level = log(min(100, $self->{'settling_turn'}));
    # if we have a lot of trees, we can chop a monument
    my $turns_to_expand_borders;
    if ($self->{'available_trees'} >= 3) {
        my ($turns_to_chop) = max(3, int(10 - $extra_help_level));
        $turns_to_expand_borders = 10 + $turns_to_chop;
        $self->{'last_chop'} = $self->{'last_chop'} + $turns_to_chop;
    }
    else {
        # otherwise, we slowbuild
        $turns_to_expand_borders = int(20 - $extra_help_level);
    }
    
    $self->{'turns_for_expansion'} = $turns_to_expand_borders + $self->{'initial_delay'};

    $self->calculate_growth_target();
    $self->{'growth_target'} = 2 if $self->{'settlement_order'} == 2;
    
    $self->choose_tiles();
}

# calculate when this city should stop growing and just 
# concentrate on producing stuff
# TODO: this SHOULD take into account shared tiles also... 
sub calculate_growth_target {
    my ($self) = @_;
    my @tiles = $self->{'center'}{'bfc'}->get_all_tiles();
    @tiles = sort { $b->{'value'} <=> $a->{'value'} } @tiles;

    my $tile_threshold = ($self->{'has_granary'}) ? 8 : 4;
    my $whip_threshold = ($self->{'has_granary'}) ? 5 : 10;
    
    my $i = 0;
    my $w = 0;
    while (1) {
        $w = $i if $tiles[$i]{'value'} > $whip_threshold;
        last if $tiles[$i]{'value'} < $tile_threshold;
        last if $i == $#tiles;
        $i ++;
    }
    
    $self->{'whip_threshold'} = $w + 1;
    $self->{'final_target'} = max(2, $i+1);
    $self->{'growth_target'} = max(2, $self->{'current_size'}, $self->{'growth_target'});
}

# process one turn; basically, we're either growing (and producing a monument/granary along the way)
# or we're building workers/settlers
sub advance_turn {
    my ($self) = @_;
    my %ret;
    
    if ($self->{'initial_delay'} > 0) {
        $self->{'initial_delay'} --;
        return \%ret;
    }
    
    # up here, this is the start of the turn where the player can control
    
    # first, we find out if we need to expand borders
    if (($self->{'borders_expanded'} == 0) and ($self->{'turns_for_expansion'} <= 0)) {
        $ret{'borders_expanded'} = 1;
        $self->{'borders_expanded'} = 1;
        $self->{'max_fpt'} = -1;
        $self->choose_tiles();
        
        # recalculate our growth target now we can work new tiles
        if (($self->{'current_status'} eq 'growth') and ($self->{'current_size'} < $self->{'growth_target'})) {
            if ($self->{'current_fpt'} <= 2) {
                $self->{'ready_to_build'} = 1;
                $self->{'growth_target'} = $self->{'current_size'};
                $self->{'final_target'} = $self->{'current_size'};
                $self->{'current_turn'} ++;
                
                $ret{'finished_growing'} = 1;
                return \%ret;
            }
        }
    }
    elsif ($self->{'borders_expanded'} == 0) {
        $self->{'turns_for_expansion'} --;
    }
    
    # --- here is where the turn ends, and the buckets fill
    
    my $turns_since_last_chop = $self->{'current_turn'} - $self->{'last_chop'};
    my $turns_since_last_whip = $self->{'current_turn'} - $self->{'last_whip'};
    
    # next, are we growing or building?
    if ($self->{'current_status'} eq 'growth') {
        # first, do we have a granary? if not, put hammers towards it, but only if we dont need a monument
        if (($self->{'has_granary'} == 0) and (($self->{'borders_expanded'} == 1) or ($self->{'turns_for_expansion'} <= 10))) {
            # do we chop for granary?
            if (($self->{'available_trees'} >= 2) and ($turns_since_last_chop >= 6) and ($self->{'hammers_for_granary'} < 50) and ($self->{'hammers_for_granary'} >= 20)) {
                $self->{'last_chop'} = $self->{'current_turn'};
                $self->{'hammers_for_granary'} += 20;
            }
            
            # or do we whip for granary?
            elsif ($self->can_whip() and ($turns_since_last_whip >= 10) and ($self->{'hammers_for_granary'} >= 30)) {
                $self->{'last_whip'} = $self->{'current_turn'};
                $self->{'hammers_for_granary'} += 30;
                $self->{'current_size'} --;
                $self->{'times_whipped'} ++;
                $self->choose_tiles();
            }
            
            $self->{'hammers_for_granary'} += $self->{'current_hpt'};
            
            # granary done
            if ($self->{'hammers_for_granary'} >= 60) {
                $self->{'has_granary'} = 1;
                $self->{'hammers_for_granary'} -= 60;
                $self->{'hammer_bin'} += $self->{'hammers_for_granary'};
                
                # calculate new target with consideration for granary
                $self->calculate_growth_target();
            }
        }
    
        # next, add food, then check to see if we grew
        $self->{'food_bin'} += $self->{'current_fpt'};
        
        # granary is now ready; we don't actually maintain the correct food count, because I'm LAZY, but then
        # we don't actually optimize for the granary build so whatever. can't do it all.
        my $food_needed_to_grow = (20 + 2*$self->{'current_size'})/(1+$self->{'granary_enabled'});
        if ($self->{'food_bin'} >= $food_needed_to_grow) {
            $self->{'food_bin'} -= $food_needed_to_grow;
            $self->{'food_bin'} += $food_needed_to_grow/4 if ($self->{'has_granary'} == 1) and ($self->{'granary_enabled'} == 0);
            $self->{'current_size'} ++;
            $self->{'times_grown'} ++;
            
            # growing after granary has completed means that we can now use it fully
            if ($self->{'has_granary'} == 1) {
                $self->{'granary_enabled'} = 1;
            }
            
            if ($self->{'current_size'} == $self->{'growth_target'}) {
                # don't choose tiles here because we'll choose them when we reconfigure
                $self->{'ready_to_build'} = 1 if $self->{'stop_settling'} == 0;
            }
            else {
                $self->choose_tiles();
            }
        }
        
        $self->{'current_turn'} ++;
        $ret{'finished_growing'} = 1 if $self->{'ready_to_build'} == 1;
        return \%ret;
    }
    
    if ($self->{'current_status'} eq 'worker') {
    
        # should we whip the worker?
        # TODO: it would be wise to whip into a granary
        if ($self->can_whip() and ($turns_since_last_whip >= 10) and ($self->{'hammer_bin'} >= 30)) {
            $self->{'hammer_bin'} += 30;
            $self->{'current_size'} --;
            $self->{'last_whip'} = $self->{'current_turn'};
            $self->{'current_size'} --;
            $self->{'times_whipped'} ++;
            $self->choose_tiles();
        }
        
        $self->{'hammer_bin'} += ($self->{'current_fpt'} + $self->{'current_hpt'});
    
        # can/should we put a chop into the worker?
        if (($self->{'available_trees'} > 0) and ($turns_since_last_chop >= 6)) {
            $self->{'hammer_bin'} += 20;
            $self->{'last_chop'} = $self->{'current_turn'};
            $self->{'available_trees'} --;
        }
        
        # the worker is done
        if ($self->{'hammer_bin'} >= 60) {
            $self->{'hammer_bin'} -= 60;
            $ret{'finished_worker'} = 1;
        }
    }   
    elsif ($self->{'current_status'} eq 'settler') {
    
        # can/should we whip?
        if ($self->can_whip() and ($turns_since_last_whip >= 10) and ($self->{'hammer_bin'} >= 70)) {
            $self->{'hammer_bin'} += 30;
            $self->{'last_whip'} = $self->{'current_turn'};
            $self->{'current_size'} --;
            $self->{'times_whipped'} ++;
            $self->choose_tiles();
        }
        
        $self->{'hammer_bin'} += ($self->{'current_fpt'} + $self->{'current_hpt'});
        
        # can/should we put a chop into the worker?
        if (($self->{'available_trees'} > 0) and ($turns_since_last_chop >= 6)) {
            $self->{'hammer_bin'} += 20;
            $self->{'last_chop'} = $self->{'current_turn'};
            $self->{'available_trees'} --;
        }
        
        # the settler is done
        if ($self->{'hammer_bin'} >= 100) {
            $self->{'hammer_bin'} -= 100;
            $ret{'finished_settler'} = 1;
        }
    }
    
    $self->{'current_turn'} ++;
    return \%ret;
}

# set all the special stuff for our capital, blah blah
sub initialize_as_capital {
    my ($self, $turn) = @_;
    $self->{'current_size'} = 3;
    $self->{'current_status'} = 'settler';
    $self->{'borders_expanded'} = 1;
    $self->{'turns_for_expansion'} = 0;
    $self->{'is_capital'} = 1;
    $self->{'last_whip'} = $turn;
    
    $self->choose_tiles();
    $self->{'hammer_bin'} = 100 - $self->{'current_fpt'} - $self->{'current_hpt'};
}

# decide what the next size this city will grow to... which might be the same size we were now
sub grow_next {
    my ($self) = @_;
    $self->{'current_status'} = 'growth';
    
    if ($self->{'stop_settling'}) {
        $self->{'ready_to_build'} = 0;
        $self->{'growth_target'} = $self->{'current_size'} + 1;
        return;
    }
    
    if ($self->{'current_size'} < $self->{'growth_target'}) {
        $self->{'ready_to_build'} = 0;
        $self->choose_tiles();
        
        if ($self->{'current_fpt'} <= 2) {
            $self->{'ready_to_build'} = 1;
            $self->{'growth_target'} = $self->{'current_size'};
            $self->{'final_target'} = $self->{'current_size'};
        }
        
        return;
    }
    
    elsif ($self->{'growth_target'} < $self->{'final_target'}) {
        $self->{'growth_target'} = $self->{'current_size'} + 1 if $self->{'current_size'} == $self->{'growth_target'}
    }
    
    $self->{'ready_to_build'} = 1 if $self->{'current_size'} >= $self->{'growth_target'};
}

# put tiles in order in terms of what the city will work based on what is available
sub choose_tiles {
    my ($self) = @_;
    
    my @tiles = ($self->{'borders_expanded'} == 1) ? $self->{'center'}{'bfc'}->get_all_tiles() : $self->{'center'}{'bfc'}->get_first_ring();
    
    # max food for growth, but don't completely ignore the other good tiles either as that wouldn't be accurate
    if ($self->{'current_status'} eq 'growth') {
        @tiles = sort { $b->{'yld'}[0] <=> $a->{'yld'}[0] } @tiles;
        
        if ($self->{'max_fpt'} == -1) {
            my $max_fpt = 2;
            foreach my $tile (@tiles) {
                if ($tile->{'yld'}[0] == 2) {
                    last;
                }
                
                $max_fpt += $tile->{'yld'}[0];
            }
            $self->{'max_fpt'} = $max_fpt;
        }
        
        my @chosen;
        while (1) {
            last if @tiles == 0;
            last if $tiles[0]{'yld'}[0] < 3;
            push @chosen, (shift @tiles);
        }
    
        @tiles = (@chosen, (sort { $b->{'value'} <=> $a->{'value'} } @tiles));
    }
    else {
        @tiles = sort { ($b->{'yld'}[0]+$b->{'yld'}[1]) <=> ($a->{'yld'}[0]+$a->{'yld'}[1]) } @tiles;
    }
    
    $self->{'current_fpt'} = 2;
    $self->{'current_hpt'} = (exists $self->{'center'}{'2h_plant'}) ? 2 : 1;
    $self->{'current_hpt'} = 2 if $self->{'is_capital'} == 1;
    
    # handle tile sharing in a really stupid and non-realistic way
    # basically, because i didn't want to figure out which city should claim what food tiles,
    # we just dither the shared tiles, substituting out the next best ones every other turn
    # because at least it doesn't double-count
    my @shared;
    my $limit = min($self->{'current_size'} - 1, $#tiles);
    foreach my $i (0 .. $limit) {
        my $tile = $tiles[$i];
        
        if ($tile->{'shared_with'}{$self->{'player'}} > 1) {
            push @shared, $tile;
            next;
        }
        
        $self->{'current_fpt'} += int($tile->{'yld'}[0]);
        $self->{'current_hpt'} += int($tile->{'yld'}[1]);
    }
    
    if (@shared > 0) {
        foreach my $i (0..$#shared) {
            my $share_f = $shared[$i]{'yld'}[0];
            my $share_h = $shared[$i]{'yld'}[1];
            my $alt_f = 0;
            my $alt_h = 2;
            
            if (($i+$limit+1) <= $#tiles) {
                $alt_f = $tiles[$i+$limit+1]{'yld'}[0];
                $alt_h = $tiles[$i+$limit+1]{'yld'}[1];
            }
            
            my $factor = 1/$shared[$i]{'shared_with'}{$self->{'player'}};
            
            my $fd = $factor*$share_f + (1-$factor)*$alt_f;
            my $hd = $factor*$share_h + (1-$factor)*$alt_h;
        
            $self->{'current_fpt'} += $fd;
            $self->{'current_hpt'} += $hd;
        }
    }
    
    $self->{'current_fpt'} = max(0, $self->{'current_fpt'} - 2*$self->{'current_size'});
}

1;