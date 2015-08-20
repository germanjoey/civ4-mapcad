package Civ4MapCad::Allocator;

use strict;
use warnings;

use List::Util qw(min max);

use Civ4MapCad::Allocator::BFC;
use Civ4MapCad::Allocator::ModelCiv;
use Algorithm::Line::Bresenham qw(line);

our %irrigatable = (
    'corn' => 1,
    'rice' => 1,
    'wheat' => 1
);

our %resource_yield = (
    'corn' => ['f', 2, 0, 0, 'f'],
    'rice' => ['f', 1, 0, 0, 'f'],
    'wheat' => ['f', 2, 0, 0, 'f'],
    'pig' => ['f', 3, 0, 0, 'f'],
    'sheep' => ['f', 2, 0, 1, 'f'],
    'cow' => ['f', 1, 2, 1, 'f'],
    'deer' => ['f', 2, 0, 0, 'f'],
    'fish' => ['f', 2, 0, 0, 'f'],
    'clam' => ['f', 1, 0, 0, 'wf'],
    'crab' => ['f', 1, 0, 0, 'wf'],
    
    'horse' => ['h', 0, 2, 1, 's'],
    'copper' => ['h', 0, 3, 0, 's'],
    'iron' => ['h', 0, 3, 0, 's'],
    'coal' => ['h', 0, 3, 0, 's'],
    'oil' => ['h', 0, 2, 1, 's'],
    'aluminum' => ['h', 0, 3, 1, 's'],
    'uranium' => ['h', 0, 0, 3, 's'],
    'marble' => ['h', 0, 1, 2, 's'],
    'stone' => ['h', 0, 2, 0, 's'],
    
    'fur' => ['c', 0, 0, 3, 'al'],
    'whale' => ['f', 0, 1, 2, 'al'],
    'ivory' => ['h', 0, 1, 1, 'al'],
    'gold' => ['c', 0, 1, 6, 'al'],
    'gems' => ['c', 0, 1, 5, 'al'],
    'silver' => ['c', 0, 1, 4, 'al'],
    
    'wine' => ['c', 1, 0, 2, 'cl'],
    'dye' => ['c', 0, 0, 4, 'cl'],
    'incense' => ['c', 0, 0, 5, 'cl'],
    'silk' => ['c', 0, 0, 3, 'cl'],
    'spices' => ['c', 1, 0, 2, 'cl'], 
    'sugar' => ['f', 1, 0, 1, 'cl'],
    'banana' => ['f', 2, 0, 0, 'wf']
);

our %bare = (
    'grass' => [2, 0, 0],
    'plains' => [1, 1, 0],
    'snow' => [0, 0, 0],
    'desert' => [0, 0, 0],
    'tundra' => [1, 0, 0],
    'coast' => [1, 0, 2],
    'ocean' => [1, 0, 1]
);

our %hidden = (
    'copper' => 35,
    'horse' => 45,
    'iron' => 90,
    'coal' => 190,
    'uranium' => 200,
    'oil' => 210,
    'aluminum' => 240
);

our %delayed = (
    'ivory' => 45,
    'deer' => 45,
    'fur' => 45,
    'whale' => 55,
    'marble' => 80,
    'stone' => 80,
    'wine' => 95,
    'silk' => 105,
    'banana' => 105,
    'incense' => 105,
    'dye' => 105,
    'spices' => 105,
    'sugar' => 105
);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($map) = @_;
    
    my $obj = bless {
        'turn' => 0,
        'map' => $map,
        'starts' => $map->find_starts(),
        'upgrade_ref' => {},
        'civs' => {},
        'resource_events' => [],
        'raycasts' => {},
        'avg_city_count' => {},
        'avg_city_value' => {}
    }, $class;
    
    $obj->initialize();
    
    return $obj;
}

sub get_width {
    my ($self) = @_;
    return $self->{'map'}->info('grid width');
}

sub get_height {
    my ($self) = @_;
    return $self->{'map'}->info('grid height');
}

sub initialize {
    my ($self) = @_;
    
    my $width = $self->get_width();
    my $height = $self->get_height();
    
    $self->{'map'}->mark_freshwater();
    $self->{'map'}->mark_continents();
    
    my %events;
    while ( my($k,$v) = each %hidden ) {
        $self->{'upgrade_ref'}{$k} = [];
        $events{$v} = 1;
    }
    
    while ( my($k,$v) = each %delayed ) {
        $self->{'upgrade_ref'}{$k} = [];
        $events{$v} = 1;
    }
    
    foreach my $start (@{ $self->{'starts'} }) {
        my ($x, $y, $player) = @$start; 
        $self->{'avg_city_count'}{$player} = 0;
        $self->{'avg_city_value'}{$player} = 0;
    }
    
    $self->{'resource_events'} = [sort {$a <=> $b} (keys %events)];
    
    foreach my $x (0 .. $width-1) {
        foreach my $y (0 .. $height-1) {
            my $tile = $self->{'map'}{'Tiles'}[$x][$y];
            $tile->{'city_available'} = 1;
            
            foreach my $start (@{ $self->{'starts'} }) {
                my ($x, $y, $player) = @$start; 
                my $line_dist = $self->{'map'}->find_line_distance_between_coords($x, $y, $tile->get('x'), $tile->get('y'));
                my $tile_dist = $self->{'map'}->find_tile_distance_between_coords($x, $y, $tile->get('x'), $tile->get('y'));
                $tile->{'distance'}{$player} = [$line_dist, $tile_dist];
                $tile->{'shared_with'}{$player} = 0;
            }
            
            $self->calculate_tile_yield($tile);
        }
    }
    
    $self->precalculate_tile_access($width, $height);
    $self->precalculate_congestion($width, $height);
    
    return;
}


            
# ok so what we're going to do is to take a look at this BFC
# and then look at the first ring.
# there's some patterns we want to look for:
# a.) multiple peaks near city center are a huge warning sign
# b.) as are lake tiles
# c.) coast less so, but still somewhat
# d.) ice/regular desert cause city spacing to grow, so they contribute some
# e.) hills are a problem too, when the city is first settled
#
# eventually what we'll do is project a line towards the nearest city and sum up the congestion
# if: a.) congestion is high near this spot but not towards our nearest city, then this is a chokepoint. if contention is high her
#     b.) if congestion is low near this city, and we're on the same continent as our nearest city, but congestion is high towards the next city, we just settled past a chokepoint. that's BAD
#     c.) if congestion is high near this spot and near the other spot, and we're on the same continent, this this is probably the other side of a big chokepoint. we don't want this either
#     d.) if congestion is low near this spot but high towards the prev city, and we have different continent ids, then this is just an overseas city. use overseas adjustment instead
#     e.) medium congestion here and at previous - sites are probably just cramped
sub precalculate_congestion {
    my ($self, $width, $height) = @_;
    
    foreach my $x (0 .. $width-1) {
        foreach my $y (0 .. $height-1) {
            my $bfc = $self->{'map'}{'Tiles'}[$x][$y]{'bfc'};
            
            my %count = (
                'lake' => 0,
                'peak' => 0,
                'hill' => 0,
                'dead' => 0,
            );
            
            foreach my $tile ($bfc->get_first_ring()) {
                if ($tile->is_water() and ($tile->{'freshwater'} == 1)) {
                    $count{'lake'} += 3;
                }
                elsif ($tile->{'PlotType'} == 0) {
                    $count{'peak'} += 3;
                }
                elsif ($tile->{'PlotType'} == 1) {
                    $count{'hill'} += 3;
                }
                elsif ((!exists $tile->{'BonusType'}) and (!exists $tile->{'FeatureType'}) and ($tile->{'TerrainType'} =~ /snow|tundra|desert/)) {
                    $count{'dead'} += 2;
                }
            }
            
            foreach my $tile ($bfc->get_second_ring()) {
                if ($tile->is_water() and ($tile->{'freshwater'} == 1)) {
                    $count{'lake'} ++;
                }
                elsif ($tile->{'PlotType'} == 0) {
                    $count{'peak'} ++;
                }
                elsif ($tile->{'PlotType'} == 1) {
                    $count{'hill'} ++;
                }
            }
            
            my $congestion = 5*$count{'peak'} + 3*$count{'lake'} + $count{'hill'} + $count{'dead'};
            $congestion /= 100; # / (5*20)
            $self->{'map'}{'Tiles'}[$x][$y]->{'congestion'} = $congestion;
        }
    }
}

sub precalculate_tile_access {
    my ($self, $width, $height) = @_;

    # casting call for ray romano
    foreach my $ddx (0..10) {
        my $dx = $ddx - 5;
        foreach my $ddy (0..10) {
            my $dy = $ddy - 5;
            next if (abs($dx) <= 2) and (abs($dy) <= 2);
            
            # line() is a call to Algorithm::Line::Bresenham::line
            $self->{'raycasts'}{$dx}{$dy} = [line(0,0 => $dx,$dy)];
        }
    }
    
    foreach my $x (0 .. $width-1) {
        foreach my $y (0 .. $height-1) {
            my $tile = $self->{'map'}{'Tiles'}[$x][$y];
            $tile->{'bfc'} = Civ4MapCad::Allocator::BFC->new($self->{'map'}, $tile);
            next if $tile->is_water();
            next if $tile->{'PlotType'} == 0;
            
            # now raycast between points to determine whether a travel line is across water or not
            foreach my $ddx (0..10) {
                my $dx = $ddx - 5;
                foreach my $ddy (0..10) {
                    my $dy = $ddy - 5;
                    
                    next if (abs($dx) <= 2) and (abs($dy) <= 2);
                    my $other_tile = $self->{'map'}->get_tile($x+$dx, $y+$dy);
                    next if exists $tile->{'access'}{$other_tile->get('x')}{$other_tile->get('y')};
                    
                    next if $other_tile->is_water();
                    next if $other_tile->{'PlotType'} == 0;
                    
                    my $ptype = 0;
                    my $path = $self->{'raycasts'}{$dx}{$dy};
                    foreach my $s (@$path) {
                        my ($ndx, $ndy) = @$s;
                        my $step = $self->{'map'}->get_tile($x+$ndx, $y+$ndy);
                        $ptype = 1 if ($ptype == 0) and ($step->{'TerrainType'} eq 'TERRAIN_COAST') and (!$step->is_fresh());
                        $ptype = 2 if ($step->{'TerrainType'} eq 'TERRAIN_OCEAN');
                    }

                    $tile->{'access'}{$other_tile->get('x')}{$other_tile->get('y')} = $ptype;
                    $other_tile->{'access'}{$tile->get('x')}{$tile->get('y')} = $ptype;
                }
            }
            
        }
    }
}

sub calculate_tile_yield {
    my ($self, $tile) = @_;
    
    my $food = 8;
    my $hammer = 5.51;
    my $beaker = 3;
    my $cost = $food*2 + 0.5*$beaker;
    
    $tile->{'member_of'} = [];
    
    if ($tile->{'PlotType'} == 0) {
        $tile->{'yld'} = [0, 0, 0];
        $tile->{'value'} = -17;
        return;
    }
    
    my $tt = lc $tile->{'TerrainType'};
    $tt =~ s/^terrain_//;
    $tile->{'yld'} = [$bare{$tt}[0], $bare{$tt}[1], $bare{$tt}[2]];
    
    if ((exists $tile->{'FeatureType'})) {
        # forest/jungle are removed when the resource is upgraded
    
        if ($tile->{'FeatureType'} eq 'FEATURE_FLOOD_PLAINS') {
            $tile->{'yld'}[0] += 3;
        }
        elsif ($tile->{'FeatureType'} eq 'FEATURE_OASIS') {
            $tile->{'yld'}[0] += 3;
            $tile->{'yld'}[2] += 2;
        }
        elsif ($tile->{'FeatureType'} eq 'FEATURE_FOREST') {
            $tile->{'yld'}[1] ++;
        }
        elsif ($tile->{'FeatureType'} eq 'FEATURE_JUNGLE') {
            $tile->{'yld'}[0] = max(0, $tile->{'yld'}[0] - 1);
        }
    }
    
    if ($tile->{'PlotType'} == 1) {
        $tile->{'yld'}[0] = max(0, $tile->{'yld'}[0] - 1);
        $tile->{'yld'}[1] ++;
        
        # TODO: this should be more sophisticated, probably
        if ($tt eq 'plains') {
            $tile->{'2h_plant'} = 1;
        }
    }
    
    if ($tile->is_water()) {
        $tile->{'yld'}[0] ++ if $tile->{'freshwater'} == 1;
    }
    elsif ($tile->is_river_adjacent()) {
        if ( (exists $tile->{'FeatureType'}) and ($tile->{'FeatureType'} eq 'FEATURE_FOREST')) {
            $tile->{'yld'}[2] ++ if exists $tile->{'BonusType'};
        }
        else {
            $tile->{'yld'}[2] ++ unless (exists $tile->{'FeatureType'}) and ($tile->{'FeatureType'} eq 'FEATURE_JUNGLE');
        }
    }
    
    if (exists $tile->{'BonusType'}) {
        my $bonus = lc $tile->{'BonusType'};
        $bonus =~ s/^bonus_//;
        $tile->{'bonus_type'} = $resource_yield{$bonus}[4];
        my $t = ($resource_yield{$bonus}[0] eq 'f') ? 0 : (($resource_yield{$bonus}[0] eq 'h') ? 1 : 2);
        
        if ($tile->is_water()) {
            $tile->{'yld'}[0] += 0.51;
        }
        
        if (exists $self->{'upgrade_ref'}{$bonus}) {
            $tile->{'up_yld'} = [];
            $tile->{'up_yld'}[0] = $tile->{'yld'}[0] + $resource_yield{$bonus}[1];
            $tile->{'up_yld'}[1] = $tile->{'yld'}[1] + $resource_yield{$bonus}[2];
            $tile->{'up_yld'}[2] = $tile->{'yld'}[2] + $resource_yield{$bonus}[3];
            
            $tile->{'base_yld'} = [$tile->{'yld'}[0], $tile->{'yld'}[1], $tile->{'yld'}[2]];
            
            $tile->{'up_yld'}[$t] ++;
            
            # subtract out forest and jungle modifiers; deer/ivory/fur get to keep their forest
            # delayed resources with jungle should have their delay-number after IW.
            $tile->{'up_yld'}[1] -- if (exists $tile->{'FeatureType'}) and ($tile->{'FeatureType'} eq 'FEATURE_FOREST') and ($bonus !~ /^(?:deer|ivory|fur)$/);
            $tile->{'up_yld'}[0] ++ if (exists $tile->{'FeatureType'}) and ($tile->{'FeatureType'} eq 'FEATURE_JUNGLE');
            
            if (exists $delayed{$bonus}) {
                $tile->{'yld'}[$t] ++;
                $tile->{'base_yld'}[$t] ++;
            }
            
            $tile->{'value'} = int($food*$tile->{'yld'}[0] + $hammer*$tile->{'yld'}[1] + $beaker*$tile->{'yld'}[2] - $cost);
            $tile->{'base_value'} = $tile->{'value'};
            $tile->{'up_value'} = int($food*$tile->{'up_yld'}[0] + $hammer*$tile->{'up_yld'}[1] + $beaker*$tile->{'up_yld'}[2] - $cost);
            
            push @{ $self->{'upgrade_ref'}{$bonus} }, $tile;
        }
        
        # jungled resources need to wait for iron
        elsif ((exists $tile->{'FeatureType'}) and ($tile->{'FeatureType'} eq 'FEATURE_JUNGLE')) {
            $tile->{'yld'}[$t] ++;
            $tile->{'base_yld'} = [$tile->{'yld'}[0], $tile->{'yld'}[1], $tile->{'yld'}[2]];;
            
            $tile->{'up_yld'} = [];
            $tile->{'up_yld'}[0] = $tile->{'yld'}[0] + $resource_yield{$bonus}[1];
            $tile->{'up_yld'}[1] = $tile->{'yld'}[1] + $resource_yield{$bonus}[2];
            $tile->{'up_yld'}[2] = $tile->{'yld'}[2] + $resource_yield{$bonus}[3];
        
            if ((exists $irrigatable{$bonus}) and $tile->is_fresh()) {
               $tile->{'up_yld'}[0] ++;
            }
            
            if ((exists $irrigatable{$bonus}) and $tile->is_fresh()) {
               $tile->{'up_yld'}[0] ++;
            }
            
            $tile->{'value'} = int($food*$tile->{'yld'}[0] + $hammer*$tile->{'yld'}[1] + $beaker*$tile->{'yld'}[2] - $cost);
            $tile->{'base_value'} = $tile->{'value'};
            $tile->{'up_value'} = int($food*$tile->{'up_yld'}[0] + $hammer*$tile->{'up_yld'}[1] + $beaker*$tile->{'up_yld'}[2] - $cost);
        
            push @{ $self->{'upgrade_ref'}{'iron'} }, $tile;
            
        }
        else {
            $tile->{'yld'}[0] += $resource_yield{$bonus}[1];
            $tile->{'yld'}[1] += $resource_yield{$bonus}[2];
            $tile->{'yld'}[2] += $resource_yield{$bonus}[3];
            $tile->{'yld'}[$t] ++;
            
            # subtract out forest modifier
            $tile->{'yld'}[1] -- if (exists $tile->{'FeatureType'}) and ($tile->{'FeatureType'} eq 'FEATURE_FOREST');
            
            if ((exists $irrigatable{$bonus}) and $tile->is_fresh()) {
               $tile->{'yld'}[0] ++;
            }
            
            $tile->{'value'} = int($food*$tile->{'yld'}[0] + $hammer*$tile->{'yld'}[1] + $beaker*$tile->{'yld'}[2] - $cost);
            
        }
        
        if (($tile->{'bonus_type'} eq 'f') and ($tile->{'yld'}[0] < 4)) {
            $tile->{'bonus_type'} = 'wf';
        }
    }
    else {
        $tile->{'value'} = int($food*$tile->{'yld'}[0] + $hammer*$tile->{'yld'}[1] + $beaker*$tile->{'yld'}[2] - $cost);
        
        # we'll use the plot value, not the yield, in determining sites
        # however, we'll want to think of hills as mined when we're determining what tiles to work
        if ($tile->{'PlotType'} == 1) {
            $tile->{'yld'}[1] += ((exists $tile->{'FeatureType'}) ? 1 : 2);
        }
        
        # likewise we'll farm where we can
        elsif (($tile->{'PlotType'} == 2) and $tile->is_fresh()) {
           $tile->{'yld'}[0] ++;
        }
    }
}

sub upgrade_resource_event {
    my ($self, $turn) = @_;
    
    my @found;
    foreach my $resource_name (keys %{ $self->{'upgrade_ref'} }) {
        if (exists $delayed{$resource_name}) {
            next if $delayed{$resource_name} != $turn;
        }
        elsif (exists $hidden{$resource_name}) {
            next if $hidden{$resource_name} != $turn;
        }
        
        foreach my $resource_tile (@{ $self->{'upgrade_ref'}{$resource_name} }) {
            $resource_tile->{'yld'}[0] = $resource_tile->{'up_yld'}[0];
            $resource_tile->{'yld'}[1] = $resource_tile->{'up_yld'}[1];
            $resource_tile->{'yld'}[2] = $resource_tile->{'up_yld'}[2];
            $resource_tile->{'value'} = $resource_tile->{'up_value'};
            
            foreach my $bfc (@{ $resource_tile->{'member_of'} }) {
                $bfc->upgrade_via_resource($resource_name);
            }
        }
        
        push @found, $resource_name;
    }
    
    foreach my $player (keys %{ $self->{'civs'} }) {
        $self->{'civs'}{$player}->choose_tiles_conditionally(@found);
    }
}

sub reset_resources {
    my ($self) = @_;
    
    my $width = $self->get_width();
    my $height = $self->get_height();
    $self->{'resource_events'} = [sort {$a <=> $b} @{ $self->{'resource_events'} }];
    
    # then reset resources
    foreach my $resource_name (keys %{ $self->{'upgrade_ref'} }) {
        foreach my $resource_tile (@{ $self->{'upgrade_ref'}{$resource_name} }) {
            $resource_tile->{'yld'}[0] = $resource_tile->{'base_yld'}[0];
            $resource_tile->{'yld'}[1] = $resource_tile->{'base_yld'}[1];
            $resource_tile->{'yld'}[2] = $resource_tile->{'base_yld'}[2];
            $resource_tile->{'value'} = $resource_tile->{'base_value'};
            
            foreach my $other_bfc (@{ $resource_tile->{'member_of'} }) {
                $other_bfc->reset();
            }
        }
    }
    
    foreach my $x (0 .. $width-1) {
        foreach my $y (0 .. $height-1) {
            $self->{'map'}{'Tiles'}[$x][$y]{'city_available'} = 1;
            
            foreach my $start (@{ $self->{'starts'} }) {
                my ($x, $y, $player) = @$start; 
                $self->{'map'}{'Tiles'}[$x][$y]{'shared_with'}{$player} = 0;
            }
        }
    }
}

sub allocate {
    my ($self, $tuning_iterations, $iterations, $to_turn, $tiles_per_player) = @_;
    
    $self->{'tuning_iterations'} = $tuning_iterations;
    $self->{'iterations'} = $iterations;
    
    $self->{'average_allocation'} = $self->create_blank_alloc();
    $self->{'estimated_allocation'} = $self->create_blank_alloc();
    
    foreach my $it (1..$tuning_iterations) {
        $self->reset_resources() if $it > 1;
        warn "starting tuning iteration $it\n";
        my $ownership = $self->allocate_single($it, $to_turn, $tiles_per_player, 0);
        
        $self->update_alloc('estimated_allocation', $tuning_iterations, $ownership, 0);
    }
    
    $self->set_contention_estimate();
        
    foreach my $it (1..$iterations) {
        $self->reset_resources();
        warn "starting actual iteration $it\n";
        my $ownership = $self->allocate_single($it, $to_turn, $tiles_per_player, 1);
        
        foreach my $civ (keys %{ $self->{'civs'} }) {
            $self->{'avg_city_count'}{$civ} += @{ $self->{'civs'}{$civ}{'cities'} }/$iterations;
            
            my $value = 0;
            foreach my $city (@{ $self->{'civs'}{$civ}{'cities'} }) {
                $value += $city->{'center'}{'bfc_value'};
            }
            
            $self->{'avg_city_value'}{$civ} += $value/$iterations;
        }
           
        $self->update_alloc('average_allocation', $iterations, $ownership, 1);
    }
}

# this is an unbiased prior of which civs will get which tiles
sub set_contention_estimate {
    my ($self) = @_;
    
    my $width = $self->get_width();
    my $height = $self->get_height();
    
    foreach my $x (0 .. $width-1) {
        foreach my $y (0 .. $height-1) {
            my $tile = $self->{'map'}{'Tiles'}[$x][$y];
            $tile->{'contention_estimate'} = $self->{'estimated_allocation'}[$x][$y];
        }
    }
    
    foreach my $x (0 .. $width-1) {
        foreach my $y (0 .. $height-1) {
            my $tile = $self->{'map'}{'Tiles'}[$x][$y];
            next if ($tile->{'PlotType'} == 0) or ($tile->{'PlotType'} == 3);
            $tile->{'bfc'}->find_expected_ownership() if exists $tile->{'bfc'};
        }
    }
}

sub create_blank_alloc {
    my ($self) = @_;
    
    my $width = $self->get_width();
    my $height = $self->get_height();
    
    my @alloc;
    foreach my $x (0 .. $width-1) {
        $alloc[$x] = [];
        foreach my $y (0 .. $height-1) {
            my %dist;
            foreach my $start (@{ $self->{'starts'} }) {
                my ($x, $y, $player) = @$start; 
                $dist{$player} = 0;
            }
            
            $alloc[$x][$y] = \%dist;
        }
    }
    
    return \@alloc;
}

sub update_alloc {
    my ($self, $which, $iterations, $ownership, $update_contention) = @_;
 
    my $width = $self->get_width();
    my $height = $self->get_height();
    
    foreach my $x (0 .. $width-1) {
        foreach my $y (0 .. $height-1) {
        
            my %found;
            my $per_player = 0;
            foreach my $player (keys %{ $ownership->[$x][$y] }) {
                if ($ownership->[$x][$y]{$player} > 0) {
                    $per_player ++;
                    $found{$player} = 1;
                }
            }
            
            next if $per_player == 0;
            $per_player = 1/($per_player*$iterations);
            
            # update bfc contention here? every X number of iterations, perhaps?
            
            foreach my $player (keys %found) {
                $self->{$which}[$x][$y]{$player} += $per_player;
            }
        }
    }
}

sub allocate_single {
    my ($self, $it, $to_turn, $tiles_per_player, $consider_estimate) = @_;
    
    # create blank allocation matrix
    my $alloc = $self->create_blank_alloc();
    
    my $width = $self->get_width();
    my $height = $self->get_height();
    
    my @open_spots;
    foreach my $x (0 .. $width-1) {
        $open_spots[$x] = [];
        foreach my $y (0 .. $height-1) {
            $open_spots[$x][$y] = 1;
        }
    }
    
    my %done;
    
    my $civs = $self->{'civs'};
    foreach my $start (@{ $self->{'starts'} }) {
        my ($x, $y, $player) = @$start;
        $civs->{$player} = Civ4MapCad::Allocator::ModelCiv->new($x, $y, $player, $tiles_per_player, $self->{'map'}, $alloc);
    }
    
    foreach my $turn (30..$to_turn) {
        if ($turn == $self->{'resource_events'}[0]) {
            $self->upgrade_resource_event($turn);
        }
    
        foreach my $player (keys %$civs) {
            my $civ = $civs->{$player};
            next if exists $done{$player};
            
            my (@settlers) = $civ->advance_turn();
            foreach my $settler (@settlers) {
                my $spots = $civ->find_prospective_sites();
                
                if (@$spots == 0) {
                    # print "* player $player is ending early on it $it turn $turn with ", $civ->city_count(), " cities\n";
                
                    $done{$player} = 1;
                    last;
                }
                
                my $num_to_consider = min($#$spots, 3 + $civ->city_count());
                
                my @stat_adjust;
                my $min = 1000000;
                foreach my $i (0 .. $num_to_consider) {
                    my $spot = $spots->[$i];
                    next unless $civ->{'starting_continent'} == $spot->{'continent_id'};
                    my $adjust = $civ->strategic_adjustment($spot, $settler, $consider_estimate);
                    $min = $adjust if $adjust < $min;
                    push @stat_adjust, [$adjust, $spot];
                }
                
                my $total = 0;
                foreach my $s (@stat_adjust) {
                    $s->[0] -= $min;
                    $s->[0] = $s->[0]**3;
                    $total += $s->[0];
                }
                
                my $choice;
                if ($total == 0) {
                    if ($spots->[0]->{'continent_id'} == $civ->{'starting_continent'}) {
                        $choice = $spots->[0];
                    }
                    else {
                        $done{$player} = 1;
                        last;
                    }
                }
                else {
                    # @stat_adjust = sort { $b->[0] <=> $a->[0] } @stat_adjust;
                
                    my $r = rand(1)*$total;
                    foreach my $i (0 .. $#stat_adjust) {
                        $r -= $stat_adjust[$i][0];
                        if ($r <= 0) {
                            $choice = $stat_adjust[$i][1];
                            last;
                        }
                    }
                }
                
                $civ->add_city($settler, $choice, $alloc);
            }
        }
    }
    
    return $alloc;
}
        
=head1
BFC assignment method for land allocation pseudocode:
    (all matrices here are 2D arrays the same size as the map)

    bfc_allocation (map) {
    
        total_allocation = new blank matrix
        foreach tile in map
            foreach civ
                total_allocation.tile.civ = 0
                tile's distance from each capital is cached
            

        # each local_allocation is one guess on what the map would look like this were an always_peace game            
        for 1..1000 # or 100 or 10000 or whatever
            local_allocation = bfc_allocation_single_step(map)
            
            foreach tile in local_allocation
                foreach civ
                    total_allocation.tile.civ += local_allocation.tile.civ
                    
        # take our 1000 guesses to get a true estimate on how likely it is a particular civ will gain a particular tile
        # in later revisions, later passes should get weighted more highly because they should be influenced by good results from previous passes
        foreach tile in total_allocation
            foreach civ
                total_allocation.tile.civ /= 1000
            
        return total_allocation
    }
    
    bfc_allocation_single_step (map) {
        local_allocation = new blank matrix 
        allocate capital BFCs in map
        
        num_allocated = num civs
        while (1) {
            if num_allocated == 0
                break 
                
            num_allocated = 0
            
            # looping through civs like this is fine for the first revision, but eventually this should be a priority queue based on
            # "settling power", which is the result of the sum of a civ's bfc-power, which new cities get added to on a time delay
            foreach civ
                potential_sites = all tiles between 3 and 6 away of any of this civ's cities
                filter potential_sites of any tiles that are less than 3 away of any other civ's cities
                
                foreach tile in potential_sites
                    calculate bfc quality of a city centered on this tile based purely on tile yields
                        - first-ring should be more valuable than second ring
                        - seafood should be rated under equivalent yield of land-tile
                        - should have flags for considering yields of copper/iron/horses
                        - should have flags for considering plantations and jungle-gems
                    
                if potential_sites == 0
                    continue
                    
                foreach bfc 
                    now factor in strategic concerns:
                        - copper's concern increases exponentially for each city after the first, then drops to 0 once copper is   
                          captured
                        - horse's concern increases exponentially for each city after the second, then drops to 0 once horse is 
                          captured
                        - iron's concern increases exponentially for each city after the eighth, then drops to 0 once iron is captured
                        - marble and stone have a high but linearly increasing concern for each city after the 5t, then drop to 0 
                          once they are captured. stone's concern drops off exponentially after the 10th city.
                        - luxuries should be considered whether they are ancient or classical and how many cities have so far
                          been settled
                        - cities closer to the capital are valued more highly than those further from it
                        - cities settled towards closer rivals are valued more highly than those settled away
                            - do we do this based on capitals or what rivals have settled already? not sure. later way is more
                              computationally intensive for sure.
                        - cities on hills are valued more highly if they are closer to rivals
                        - eventually, for later revisions, sites from previous passes that were found to be good should be weighted higher
                        
                # now we have a score for each potential site
                
                pick the top 10 sites
                
                total = 0
                foreach site 
                    total += (site's score)^2
                
                foreach site
                    settling_probability = (site's score)^2 / total
                    
                # now we have a settling probability for each site
                pick a random site based on their weight - our "blue circle"
                
                allocate that BFC for that civ onto local_allocation.
                (if the bfc overlaps with the bfc from another civ, these overlapped tiles should be allocated to both)
                num_allocated ++
                
        return local_allocation
    }
=cut