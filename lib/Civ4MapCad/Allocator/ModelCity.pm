package Civ4MapCad::Allocator::ModelCity;

use strict;
use warnings;

use List::Util qw(min max);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($player, $center, $turn, $order, $initial_delay, $prob, $settler) = @_;
    
    my $obj = bless {
        'prob' => $prob,
        'settler_from' => $settler,
        'player' => $player,
        'center' => $center,
        'settlement_order' => $order,
        'settling_turn' => ($turn + $initial_delay),
        'current_turn' => ($turn + $initial_delay),
        'last_chop' => ($turn + $initial_delay),
        'last_whip' => ($turn + $initial_delay), 
        'is_capital' => 0,
        
        'available_trees' => int($center->{'bfc'}->count_trees()/2 + 0.5),
        'initial_delay' => $initial_delay,
        'max_fpt' => -1,
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
        'blocked_tiles' => {},
        'aborting_growth' => 0,
        'currently_worked' => [],
        
        'hammers_for_granary' => 0,
        'has_granary' => 0,
        'granary_enabled' => 0,
        
        'turns_for_expansion' => 0, # border expansion
        'borders_expanded' => 0,
    }, $class;
    
    $obj->initialize();
    
    return $obj;
}

sub debug {
    my ($self, $bo) = @_;
    
    print $bo "CITY INDEX: $self->{'settlement_order'}, settling_turn:$self->{'settling_turn'}, current_turn:$self->{'current_turn'}\n";
    print $bo "  center: $self->{'center'}{'x'} $self->{'center'}{'y'}, bfc value: ", sprintf('%6.4f', $self->{'center'}{'bfc_value'}), "\n";
    print $bo "  settler from: $self->{'settler_from'}{'x'} $self->{'settler_from'}{'y'}\n";
    print $bo "  settling probability: $self->{'prob'}\n";
    print $bo "  borders: $self->{'borders_expanded'}, turns_for_expansion: $self->{'turns_for_expansion'}, is_capital: $self->{'is_capital'}\n";
    print $bo "  size: $self->{'current_size'}, growth_target: $self->{'growth_target'}, final_target: $self->{'final_target'} \n";
    print $bo "  food_bin: $self->{'food_bin'}, current_fpt: $self->{'current_fpt'}, max_fpt: $self->{'max_fpt'} \n";
    print $bo "  hammer_bin: $self->{'hammer_bin'}, current_hpt: $self->{'current_hpt'}\n";
    print $bo "  has_granary: $self->{'has_granary'}, granary_enabled: $self->{'granary_enabled'}, hammers_for_granary: $self->{'hammers_for_granary'}\n";
    print $bo "  current_status: $self->{'current_status'}, ready_to_build: $self->{'ready_to_build'}, stop_settling: $self->{'stop_settling'}, aborting_growth: $self->{'aborting_growth'}\n";
    print $bo "  last_whip: $self->{'last_whip'}, times_whipped: $self->{'times_whipped'}, times_grown: $self->{'times_grown'}\n";
    print $bo "  last_chop: $self->{'last_chop'}, available_trees: $self->{'available_trees'}\n";
    print $bo "  blocked_tiles: ";
    
    foreach my $x (keys %{ $self->{'blocked_tiles'} }) {
        foreach my $y (keys %{ $self->{'blocked_tiles'}{$x} }) {
            print $bo "$x,$y ";
        }
    }
    
    print $bo "\n";
    
    if ($self->{'initial_delay'} > 0) {
        print $bo "  this city is not yet working tiles.\n\n\n";
        return;
    }
    
    print $bo "\n  best tiles:\n";
    my $i = 0;
    my @tiles = $self->get_real_yield_tiles();
    foreach my $tile (sort {$b->{'real_value'} <=> $a->{'real_value'}} @tiles) {
        no warnings;
        my $cell = $tile->to_cell();
        my ($title) = $cell =~ /title\s*=\s*"([^"]+)\"/;
        print $bo "    $title, current yld: $tile->{'real_yld'}[0]/$tile->{'real_yld'}[1]/$tile->{'real_yld'}[2], metric value: $tile->{'value'}, used value: $tile->{'real_value'} ";
        
        if (exists $self->{'blocked_tiles'}{$tile->{'x'}}{$tile->{'y'}}) {
            print $bo "BLOCKED\n";
            next;
        }
        
        $i++;
        last if $i > $self->{'current_size'};
        print $bo "\n";
    }
    
    print $bo "\n\n";
    print $bo "  currently worked tiles:\n";
    foreach my $tile (@{ $self->{'currently_worked'} }) {
        my $cell = $tile->to_cell();
        my ($title) = $cell =~ /title\s*=\s*"([^"]+)\"/;
        print $bo "    $title, current yld: $tile->{'real_yld'}[0]/$tile->{'real_yld'}[1]/$tile->{'real_yld'}[2], metric value: $tile->{'value'}, used value: $tile->{'real_value'}\n";
    }
    
    print $bo "\n\n";
}

sub get_center {
    my ($self) = @_;
    return $self->{'center'}
}

sub get_settlement_turn {
    my ($self) = @_;
    return $self->{'settling_turn'};
}

sub set_blockage {
    my ($self, $blocked, $claimed) = @_;
    
    my $different = 0;
    foreach my $x (keys %{ $self->{'blocked_tiles'} }) {
        foreach my $y (keys %{ $self->{'blocked_tiles'}{$x} }) {
            $different = 1 if exists $claimed->{$x}{$y};
        }
    }
    
    foreach my $x (keys %$blocked) {
        foreach my $y (keys %{ $blocked->{$x} }) {
            $different = 1 if ! exists $self->{'blocked_tiles'}{$x}{$y};
        }
    }
    
    if ($different == 1) {
        $self->{'blocked_tiles'} = $blocked;
        $self->calculate_growth_target();
        $self->choose_tiles();
        
        if (($self->{'current_status'} eq 'growth') and ($self->{'current_fpt'} <= 2) and ($self->{'borders_expanded'} == 1) and ($self->{'current_size'} >= 2)) {
            $self->{'ready_to_build'} = 1;
            $self->{'growth_target'} = $self->{'current_size'};
            $self->{'final_target'} = $self->{'current_size'};
            $self->{'aborting_growth'} = 1;
        }
    }
}

sub has_stopped_settling {
    my ($self) = @_;
    return $self->{'stop_settling'};
}

sub has_expanded_borders {
    my ($self) = @_;
    return $self->{'borders_expanded'};
}

sub can_whip {
    my ($self) = @_;
    return 0 if $self->{'max_fpt'} < 3;
    return 0 if $self->{'last_whip'} < 10;
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
    
    if ($self->{'aborting_growth'} == 1) {
        $self->{'aborting_growth'} = 0;
        $self->{'turn'} --;
        $self->advance_turn();
        
    }
    
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
    if ($self->{'available_trees'} >= 2) {
        my ($turns_to_chop) = max(3, int(10 - $extra_help_level));
        $turns_to_expand_borders = 10 + $turns_to_chop;
        $self->{'last_chop'} = $self->{'last_chop'} + $turns_to_chop;
    }
    else {
        # otherwise, we slowbuild
        $turns_to_expand_borders = int(20 - $extra_help_level);
    }
    
    $self->{'turns_for_expansion'} = $turns_to_expand_borders;

    $self->calculate_growth_target();
    $self->{'growth_target'} = 2 if $self->{'settlement_order'} == 2;
    
    $self->choose_tiles();
}

# set all the special stuff for our capital, blah blah
sub initialize_as_capital {
    my ($self, $turn) = @_;
    $self->{'current_size'} = 3;
    $self->{'initial_delay'} = 0;
    $self->{'current_status'} = 'settler';
    $self->{'borders_expanded'} = 1;
    $self->{'turns_for_expansion'} = 0;
    $self->{'is_capital'} = 1;
    $self->{'last_whip'} = $turn + 4;
    $self->{'last_chop'} = $turn + 4;
    
    $self->choose_tiles();
    $self->{'hammer_bin'} = 100 - $self->{'current_fpt'} - $self->{'current_hpt'};
}

# calculate when this city should stop growing and just concentrate on producing stuff
sub calculate_growth_target {
    my ($self) = @_;
    
    $self->calculate_max_fpt();
    
    my @tiles = $self->{'center'}{'bfc'}->get_all_tiles();
    @tiles = sort { $b->{'value'} <=> $a->{'value'} } @tiles;
    @tiles = grep {! exists $self->{'blocked_tiles'}{$_->{'x'}}{$_->{'y'}} } @tiles;

    # these are tile values
    # the first is the least valueable tile we want to grow up to
    # the second is what value of tiles we're allowed to "whip away"
    my $tile_threshold = ($self->{'has_granary'}) ? 3 : 6;
    my $whip_threshold = ($self->{'has_granary'}) ? 5 : 10;
    
    my $i = 0;
    my $w = 0;
    while (1) {
        $w = $i if $tiles[$i]{'value'} > $whip_threshold;
        last if $tiles[$i]{'value'} < $tile_threshold;
        last if $i >= $#tiles;
        $i ++;
    }
    
    $self->{'whip_threshold'} = $w + 1;
    $self->{'final_target'} = min(8, max(2, $i+1));
    $self->{'growth_target'} = min(8, max(2, $self->{'current_size'}, $i));
}

# this is called whenever we a.) hit a growth target or b.) finish producing something
sub grow_next {
    my ($self) = @_;
    $self->{'current_status'} = 'growth';
    
    # if we stopped settling, once we can finished our last build we never go back to producing workers/settlers, just growing forever
    if ($self->{'stop_settling'}) {
        $self->{'ready_to_build'} = 0;
        $self->{'growth_target'} = $self->{'current_size'} + 1;
        return;
    }
    
    # if we still have good tiles left to grow on, we keep growing
    if ($self->{'current_size'} < $self->{'growth_target'}) {
        $self->{'ready_to_build'} = 0;
        $self->choose_tiles();
        
        # catch problem where our current_fpt drops too low to make it to our growth target
        # thus we force ourselves to stop growing forever, unless something recalculates our growth target
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

sub calculate_max_fpt {
    my ($self) = @_;
    
    my @tiles = ($self->{'borders_expanded'} == 1) ? $self->{'center'}{'bfc'}->get_all_tiles() : $self->{'center'}{'bfc'}->get_first_ring();
    @tiles = sort { $b->{'yld'}[0] <=> $a->{'yld'}[0] } @tiles;
    
    my $max_fpt = 2;
    foreach my $tile (@tiles) {
        next if exists $self->{'blocked_tiles'}{$tile->{'x'}}{$tile->{'y'}}; 
        if ($tile->{'yld'}[0] <= 2) {
            last;
        }
        
        $max_fpt += ($tile->{'yld'}[0] - 2);
    }
    
    $self->{'max_fpt'} = $max_fpt;
}

sub get_real_yield_tiles {
    my ($self) = @_;
    
    my @tiles = ($self->{'borders_expanded'} == 1) ? $self->{'center'}{'bfc'}->get_all_tiles() : $self->{'center'}{'bfc'}->get_first_ring();
    my $turndiff = $self->{'current_turn'} - $self->{'settling_turn'};
    
    # upgrade water and wooded tiles
    foreach my $tile (@tiles) {
        $tile->{'real_yld'} = [$tile->{'yld'}[0], $tile->{'yld'}[1], $tile->{'yld'}[2]];
        
        if ($tile->is_water()) {
        # give water tiles their full food bonus
            if (exists $tile->{'BonusType'}) {
                $tile->{'real_yld'}[0] = int($tile->{'real_yld'}[0] + 0.5);
            }
            
            # activate a lighthouse
            if (($self->{'center'}{'bfc'}{'first_ring_coastal'} == 1) and ($turndiff >= $main::config{'free_lighthouse'})) {
                $tile->{'real_yld'}[0] ++;
            }
            
            $tile->{'real_value'} = $main::config{'value_per_food'}*$tile->{'real_yld'}[0] + $main::config{'value_per_hammer'}*$tile->{'real_yld'}[1] + $main::config{'value_per_beaker'}*$tile->{'real_yld'}[2];
            $tile->{'real_value'} -= (2*$main::config{'value_per_food'} + 0.5*$main::config{'value_per_beaker'});
        }
        
        # clear forests and either mine, farm, or cottage them
        elsif ((! exists $tile->{'BonusType'}) and (exists $tile->{'FeatureType'})) {
            if (($tile->{'FeatureType'} eq 'FEATURE_JUNGLE') and ($self->{'current_turn'} >= ($Civ4MapCad::Allocator::hidden{'iron'} + 10))) {
                if ($tile->{'PlotType'} == 1) {
                    $tile->{'real_yld'}[0] += 1;
                    $tile->{'real_yld'}[1] += 2;
                }
                elsif ($tile->{'PlotType'} == 2) {
                    $tile->{'real_yld'}[0] += ($tile->is_fresh() ? 2 : 1);
                    $tile->{'real_yld'}[2] ++ if ! $tile->is_fresh();
                }
            }
            elsif (($tile->{'FeatureType'} eq 'FEATURE_FOREST') and ($turndiff > $main::config{'yield_clear'})) {
                $tile->{'real_yld'}[1] --;
                    
                if ($tile->{'PlotType'} == 1) {
                    $tile->{'real_yld'}[1] += 2;
                }
                elsif ($tile->{'PlotType'} == 2) {
                    $tile->{'real_yld'}[0] ++ if $tile->is_fresh();
                    $tile->{'real_yld'}[2] ++ if ! $tile->is_fresh();
                }
            }
            elsif (($tile->{'FeatureType'} eq 'FEATURE_FLOOD_PLAINS') and ($turndiff > $main::config{'yield_clear'})) {
                $tile->{'real_yld'}[0] ++;
            }
            
            $tile->{'real_value'} = $main::config{'value_per_food'}*$tile->{'real_yld'}[0] + $main::config{'value_per_hammer'}*$tile->{'real_yld'}[1] + $main::config{'value_per_beaker'}*$tile->{'real_yld'}[2];
            $tile->{'real_value'} -= (2*$main::config{'value_per_food'} + 0.5*$main::config{'value_per_beaker'});
        }
        else {
            if ($turndiff > $main::config{'yield_clear'}) {
                if ($tile->{'PlotType'} == 1) {
                    $tile->{'real_yld'}[1] += 2;
                    $tile->{'real_value'} = $tile->{'value'} + 2*$main::config{'value_per_hammer'};
                }
                elsif ($tile->{'PlotType'} == 2) {
                    if ($tile->is_fresh()) {
                        $tile->{'real_yld'}[0] ++;
                        $tile->{'real_value'} = $tile->{'value'} + $main::config{'value_per_food'};
                    }
                    else {
                        $tile->{'real_yld'}[2] ++;
                        $tile->{'real_value'} = $tile->{'value'} + $main::config{'value_per_beaker'};
                    }
                }
                else {
                    $tile->{'real_value'} = $tile->{'value'};
                }
            }
            else {
                $tile->{'real_value'} = $tile->{'value'};
            }
        }
    }
    
    return @tiles;
}

# put tiles in order in terms of what the city will work based on what is available
sub choose_tiles {
    my ($self, $recalc_fpt) = @_;
    
    my @tiles = $self->get_real_yield_tiles();
    
    # max food for growth, but don't completely ignore the other good tiles either as that wouldn't be accurate
    if ($self->{'current_status'} eq 'growth') {
        $self->calculate_max_fpt() if $self->{'max_fpt'} < 0;
        
        @tiles = sort { $b->{'real_yld'}[0] <=> $a->{'real_yld'}[0] }
                 grep { ! exists $self->{'blocked_tiles'}{$_->{'x'}}{$_->{'y'}} }
                 @tiles;
        
        my @chosen;
        while (1) {
            last if @tiles == 0;
            last if $tiles[0]{'real_yld'}[0] < 3;
            push @chosen, (shift @tiles);
        }
    
        @tiles = (@chosen, (sort { $b->{'real_value'} <=> $a->{'real_value'} } @tiles));
    }
    else {
        @tiles = sort { ($b->{'real_yld'}[0]+$b->{'real_yld'}[1]) <=> ($a->{'real_yld'}[0]+$a->{'real_yld'}[1]) }
                 grep { ! exists $self->{'blocked_tiles'}{$_->{'x'}}{$_->{'y'}} }
                 @tiles;
    }
    
    $self->{'current_fpt'} = ((exists $self->{'center'}{'bonus_type'}) and ($self->{'center'}{'bonus_type'} =~ /f/)) ? 3  : 2;
    $self->{'current_hpt'} = (exists $self->{'center'}{'2h_plant'}) ? 2 : 1;
    $self->{'current_hpt'} = 2 if ($self->{'is_capital'} == 1) and ($main::config{'2h_capital'} == 1);
    
    $self->{'currently_worked'} = [];
    my $limit = min($self->{'current_size'} - 1, $#tiles);
    foreach my $i (0 .. $limit) {
        my $tile = $tiles[$i];
        next if exists $self->{'blocked_tiles'}{$tile->get('x')}{$tile->get('y')}; 
        
        $self->{'current_fpt'} += int($tile->{'real_yld'}[0]);
        $self->{'current_hpt'} += int($tile->{'real_yld'}[1]);
        push @{ $self->{'currently_worked'} }, $tile;
    }
    
    # TODO: if current_fpt is negative, the algorithm should probably backtrack tiles until fpt is equal to 0
    $self->{'real_fpt'} = $self->{'current_fpt'} - 2*$self->{'current_size'};
    $self->{'current_fpt'} = max(0, $self->{'real_fpt'});
}

sub advance_borders {
    my ($self) = @_;
    
    if ($self->{'initial_delay'} > 1) {
        $self->{'initial_delay'} --;
        return 0;
    }
    elsif ($self->{'initial_delay'} == 1) {
        $self->{'initial_delay'} --;
         return 1;
    }

    # on certain turns tile values increase, so we should recalculate which tiles we are working based on the new yields
    my $turndiff = $self->{'current_turn'} - $self->{'settling_turn'};
    if (($turndiff == ($main::config{'free_lighthouse'}+1)) or ($turndiff == ($main::config{'yield_clear'}+1))) {
        $self->choose_tiles();
    }
    
    # first, we find out if we need to expand borders
    if (($self->{'borders_expanded'} == 0) and ($self->{'turns_for_expansion'} <= 0)) {
        $self->{'borders_expanded'} = 1;
        return 1
    }
    elsif ($self->{'borders_expanded'} == 0) {
        $self->{'turns_for_expansion'} --;
    }
    
    return 0;
}

# process one turn; basically, we're either growing (and producing a monument/granary along the way)
# or we're building workers/settlers
sub advance_turn {
    my ($self) = @_;
    
    return {} if $self->{'initial_delay'} > 0;
    return {} if $self->{'aborting_growth'} == 1;
    
    my %ret;
    my $turns_since_last_chop = $self->{'current_turn'} - $self->{'last_chop'};
    
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
            elsif ($self->can_whip() and ($self->{'hammers_for_granary'} >= 30)) {
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
        if ($self->can_whip() and ($self->{'hammer_bin'} >= 30)) {
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
        
        # the worker is done
        if ($self->{'hammer_bin'} >= 60) {
            $self->{'hammer_bin'} -= 60;
            $ret{'finished_worker'} = 1;
        }
    }   
    elsif ($self->{'current_status'} eq 'settler') {
    
        # can/should we whip?
        if ($self->can_whip() and ($self->{'hammer_bin'} >= 70)) {
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

1;