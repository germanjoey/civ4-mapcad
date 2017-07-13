package Civ4MapCad::Allocator;

use strict;
use warnings;

use List::Util qw(min max);

use Civ4MapCad::Allocator::BFC;
use Civ4MapCad::Allocator::ModelCiv;
use Algorithm::Line::Bresenham qw(line);

# stuff that gets +1 food with freshwater
our %irrigatable = (
    'corn' => 1,
    'rice' => 1,
    'wheat' => 1
);

# yields for all tiles 
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
    'banana' => ['f', 2, 0, 0, 'wf'],
    
    'drama' => ['f', 2, 0, 0, 'f'],
    'music' => ['f', 2, 0, 0, 'f'],
    'movies' => ['f', 2, 0, 0, 'f'],
);

# bare tile yields
our %bare = (
    'grass' => [2, 0, 0],
    'plains' => [1, 1, 0],
    'snow' => [0, 0, 0],
    'desert' => [0, 0, 0],
    'tundra' => [1, 0, 0],
    'coast' => [1, 0, 2],
    'ocean' => [1, 0, 1]
);

# this is a table of turns that these resources get revealed on
our %hidden = (
    'copper' => 35,
    'horse' => 45,
    'iron' => 90,
    'coal' => 190,
    'uranium' => 200,
    'oil' => 210,
    'aluminum' => 240
);

# this is a table of turns that these resources get activated on
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

# new starts all the precalculation; see allocate for what this does
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
        'avg_city_value' => {},
        'island_settled' => {},
        'resource_event_pointer' => 0,
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

# here we precalculate all sorts of stuff so that our algorithm
# doesnt waste time doing it over and over and over each iteration
sub initialize {
    my ($self) = @_;
    
    # initial precaches
    %Civ4MapCad::ModelCiv::dist_cache = ();
    $Civ4MapCad::ModelCiv::map_width = $self->get_width();
    $Civ4MapCad::ModelCiv::map_height = $self->get_height();
    $Civ4MapCad::ModelCiv::map_wrapsX = $self->{'map'}->wrapsX();
    $Civ4MapCad::ModelCiv::map_wrapsY = $self->{'map'}->wrapsY();
    
    if ($Civ4MapCad::ModelCiv::map_wrapsX == 0) {
        $self->{'map'}{'MapInfo'}{'wrap X'} = 0;
    }
    
    if ($Civ4MapCad::ModelCiv::map_wrapsY == 0) {
        $self->{'map'}{'MapInfo'}{'wrap Y'} = 0;
    }
    
    my $width = $self->get_width();
    my $height = $self->get_height();
    my $wrapsX = $self->{'map'}->wrapsX();
    my $wrapsY = $self->{'map'}->wrapsY();
    
    $self->{'map'}->mark_freshwater();
    $self->{'map'}->mark_continents();
    
    # collect resource tiles that upgrade their value later
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
        $self->{'island_settled'}{$player} = [];
        $self->{'avg_city_count'}{$player} = 0;
        $self->{'avg_city_value'}{$player} = 0;
    }
    
    $self->{'resource_events'} = [sort {$a <=> $b} (keys %events)];
    
    # precalculate distance from each tile to each capital, both in terms of tile distance and straight-line-distance
    # (diagonals being distance 1 for tile-distance)
    
    foreach my $x (0 .. $width-1) {
        foreach my $y (0 .. $height-1) {
            my $tile = $self->{'map'}{'Tiles'}[$x][$y];
            $tile->{'city_available'} = 1;
            $tile->{'real_calc_done'} = 0;
            
            foreach my $start (@{ $self->{'starts'} }) {
                my ($x, $y, $player) = @$start; 
                my $line_dist = $self->{'map'}->find_line_distance_between_coords($width, $height, $wrapsX, $wrapsY, $x, $y, $tile->{'x'}, $tile->{'y'});
                my $tile_dist = $self->{'map'}->find_tile_distance_between_coords($width, $height, $wrapsX, $wrapsY, $x, $y, $tile->{'x'}, $tile->{'y'});
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
# eventually what we'll do is project a line towards the nearest city and sum
# up the congestion along it, making decisions on whether we're settling
# past a chokepoint based on that

sub precalculate_congestion {
    my ($self, $width, $height) = @_;
    
    foreach my $x (0 .. $width-1) {
        foreach my $y (0 .. $height-1) {
            my $spot = $self->{'map'}{'Tiles'}[$x][$y];
            my $bfc = $spot->{'bfc'};
            
            my %count = (
                '1st' => {
                    'lake' => 0,
                    'coast' => 0,
                    'peak' => 0,
                    'hill' => 0,
                    'dead' => 0,
                },
                '2nd' => {
                    'lake' => 0,
                    'peak' => 0
                }
            );
            
            foreach my $tile ($bfc->get_first_ring()) {
                if ($tile->is_water() and ($tile->{'freshwater'} == 1)) {
                    $count{'1st'}{'lake'} ++;
                }
                elsif ($tile->is_water()) {
                    $count{'1st'}{'coast'} ++;
                }
                elsif ($tile->{'PlotType'} == 0) {
                    $count{'1st'}{'peak'} ++;
                }
                elsif ($tile->{'PlotType'} == 1) {
                    $count{'1st'}{'hill'} ++;
                }
                elsif ((!exists $tile->{'BonusType'}) and (!exists $tile->{'FeatureType'}) and ($tile->{'TerrainType'} =~ /snow|tundra|desert/) and (!$tile->is_fresh())) {
                    $count{'1st'}{'dead'} ++;
                }
            }
            
            foreach my $tile ($bfc->get_second_ring()) {
                if ($tile->is_water() and ($tile->{'freshwater'} == 1)) {
                    $count{'2nd'}{'lake'} ++;
                }
                elsif ($tile->{'PlotType'} == 0) {
                    $count{'2nd'}{'peak'} ++;
                }
            }
            
            my $congestion = 0;
            if ($spot->is_water()) {
                $congestion = 2*$count{'1st'}{'coast'} + 3*$count{'1st'}{'lake'} + 5*$count{'1st'}{'peak'};
                
            }
            else {
                $congestion = 12*$count{'1st'}{'peak'} + 4*$count{'2nd'}{'peak'} + 10*$count{'1st'}{'lake'} + 3*$count{'2nd'}{'lake'} + 3*$count{'1st'}{'hill'} + 2*$count{'1st'}{'dead'};
            
                # coast isn't indicitive of congestion by itself, but it is when there are other signs
                my $impassable_1st = $count{'1st'}{'coast'} + $count{'1st'}{'lake'} + $count{'1st'}{'peak'};
                
                if ($impassable_1st > 3) {
                    $congestion += 3*$count{'1st'}{'coast'};
                    $congestion = $congestion*(1 + ($impassable_1st-2)/8);
                }
            }
            
            $congestion /= 100;
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
            next if (abs($dx) <= 1) and (abs($dy) <= 1);
            
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
                    my $other_tile = $self->{'map'}->get_tile($x+$dx, $y+$dy);
                    next unless defined($other_tile);
                    next if $other_tile->is_water();
                    
                    next if (abs($dx) <= 2) and (abs($dy) <= 2) and ($tile->{'continent_id'} == $other_tile->{'continent_id'});
                    next if exists $tile->{'access'}{$other_tile->{'x'}}{$other_tile->{'y'}};
                    
                    # next if $other_tile->{'PlotType'} == 0;
                    
                    my $ptype = 0;
                    my $path = $self->{'raycasts'}{$dx}{$dy};
                    foreach my $s (@$path) {
                        my ($ndx, $ndy) = @$s;
                        my $step = $self->{'map'}->get_tile($x+$ndx, $y+$ndy);
                        $ptype = 1 if ($ptype == 0) and ($step->{'TerrainType'} eq 'TERRAIN_COAST') and (!$step->is_fresh());
                        $ptype = 2 if ($step->{'TerrainType'} eq 'TERRAIN_OCEAN');
                    }

                    $tile->{'access'}{$other_tile->{'x'}}{$other_tile->{'y'}} = $ptype;
                    $other_tile->{'access'}{$tile->{'x'}}{$tile->{'y'}} = $ptype;
                }
            }
            
        }
    }
}

sub calculate_tile_yield {
    my ($self, $tile) = @_;
    
    my $food = $main::config{'value_per_food'};
    my $hammer = $main::config{'value_per_hammer'};
    my $beaker = $main::config{'value_per_beaker'};
    my $cost = $food*2 + 0.5*$beaker;
    
    $tile->{'member_of'} = [];
    
    if ($tile->{'PlotType'} == 0) {
        $tile->{'yld'} = [0, 0, 0];
        $tile->{'value'} = int($cost);
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
            $tile->{'yld'}[0] += $main::config{'seafood_adjust'};
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
            $tile->{'base_yld'} = [$tile->{'yld'}[0], $tile->{'yld'}[1], $tile->{'yld'}[2]];
            $tile->{'bonus_type'} = 'cl' if $tile->{'bonus_type'} eq 'al';
            
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
    }
}

sub has_resource_event {
    my ($self, $turn) = @_;
    
    return 0 if $turn > $self->{'resource_events'}[-1];
    return $turn == $self->{'resource_events'}[$self->{'resource_event_pointer'}];
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
    
    return if @found == 0;
    
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
                $other_bfc->reset_bfc();
            }
        }
    }
    
    foreach my $x (0 .. $width-1) {
        foreach my $y (0 .. $height-1) {
            $self->{'map'}{'Tiles'}[$x][$y]{'city_available'} = 1;
            $self->{'map'}{'Tiles'}[$x][$y]->{'real_calc_done'} = 0;
            
            foreach my $start (@{ $self->{'starts'} }) {
                my ($x, $y, $player) = @$start; 
                $self->{'map'}{'Tiles'}[$x][$y]{'shared_with'}{$player} = 0;
            }
        }
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

sub finalize_alloc {
    my ($self, $which) = @_;
 
    my $width = $self->get_width();
    my $height = $self->get_height();
    
    foreach my $x (0 .. $width-1) {
        foreach my $y (0 .. $height-1) {
            my $total = 0;
            foreach my $player (keys %{ $self->{$which}[$x][$y] }) {
                $total += $self->{$which}[$x][$y]{$player};
            }
            
            next if ($total == 0) or ($total == 1);
            
            foreach my $player (keys %{ $self->{$which}[$x][$y] }) {
                $self->{$which}[$x][$y]{$player} /= $total;
            }
        }
    }
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

# This here is our Markov-Chain Monte Carlo method for guessing at what players will get what land
# essentially we have little AI-bots that go around settling cities in an Always-Peace game, and
# then we talley up what they settle and how often, and that's our estimate.  we run the
# simulation hundreds of times, and the more we run it the more accurate the numbers get. the
# simulation isn't, like, perfect, but its good enough, fair, and it does incorporate a fairly
# deep settling strategy, so hopefully it will model fairly well how real human players would
# settle too. The goal of this is all to understand the map better so that the map designer
# can make better decisions about how well its balanced.
sub allocate {
    my ($self, $tuning_iterations, $iterations, $to_turn) = @_;
    
    $self->{'tuning_iterations'} = $tuning_iterations;
    $self->{'iterations'} = $iterations;
    
    $self->{'average_allocation'} = $self->create_blank_alloc();
    $self->{'estimated_allocation'} = $self->create_blank_alloc();
    
    # tuning: running a bunch of iterations to gain an estimate of how
    # each player will settle so we can use that in a contention estimate
    foreach my $it (1..$tuning_iterations) {
        $self->reset_resources() if $it > 1;
        print "        starting tuning iteration $it.\n";
        
        # iterating to turn 220 is a bit arbitrary here; the idea is to let it run until we
        # pretty much run out of tiles to get a good idea whose is whose
        my $ownership = $self->allocate_single($it, 220, 0);
        
        $self->update_alloc('estimated_allocation', $tuning_iterations, $ownership, 0);
    }
    
    print "\n";
    $self->finalize_alloc('estimated_allocation');
    $self->set_contention_estimate();
        
    # now here's the real deal
    foreach my $it (1..$iterations) {
        $self->reset_resources();
        print "        starting actual iteration $it.\n";
        my $ownership = $self->allocate_single($it, $to_turn, 1);
        
        foreach my $civ (keys %{ $self->{'civs'} }) {
            $self->{'avg_city_count'}{$civ} += @{ $self->{'civs'}{$civ}{'cities'} }/$iterations;
            
            my $value = 0;
            foreach my $city (@{ $self->{'civs'}{$civ}{'cities'} }) {
                $value += $city->{'center'}{'bfc_value'};
            }
            
            $self->{'avg_city_value'}{$civ} += $value/$iterations;
            
            if (exists $self->{'civs'}{$civ}{'island_settled'}) {
                push @{ $self->{'island_settled'}{$civ} }, $self->{'civs'}{$civ}{'island_settled'}
            }
            else {
                push @{ $self->{'island_settled'}{$civ} }, []
            }
            
            delete $self->{'civs'}{$civ}{'island_settled'};
        }
           
        $self->update_alloc('average_allocation', $iterations, $ownership, 1);
    }
}

# our single MC step, which is itself a big stochastic process to compute a probability each player will settle a
# particular tile. so, this is actually a set of w*h markov chains that we're simulating in parallel. interestingly,
# we could consider each individual run as a markov-chain of order m for determining the shape of the civ's borders,
# if anyone cares, which is probably not, because each settling probability only depends the last m cities
sub allocate_single {
    my ($self, $it, $to_turn, $consider_estimate) = @_;
    
    # create blank allocation matrix
    my $alloc = $self->create_blank_alloc();
    $self->{'resource_event_pointer'} = 0;
    
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
        $civs->{$player} = Civ4MapCad::Allocator::ModelCiv->new($x, $y, $player, $self->{'map'}, $self->{'raycasts'}, $alloc);
    }
    
    my @sorted_civs = sort {$a <=> $b} (keys %$civs);
    foreach my $turn (30..$to_turn) {
        # warn "TURN: $turn\n";
    
        if ($self->has_resource_event($turn)) {
            $self->upgrade_resource_event($turn);
            $self->{'resource_event_pointer'} ++;
        }
        
        foreach my $player (@sorted_civs) {
            my $civ = $civs->{$player};
            next if exists $done{$player};
            
            my (@settlers) = $civ->advance_turn();
            foreach my $settler (@settlers) {
                my $spots = $civ->find_prospective_sites();
                
                next unless @$spots > 0;
                
                # adjust city settling priority based on the civ's strategic desires
                my @stat_adjust;
                foreach my $i (0 .. $#$spots) {
                    my $spot = $spots->[$i];
                    my $adjust = $civ->strategic_adjustment($spot, $settler, $consider_estimate);
                    #warn "ps1 $spot->{'x'} $spot->{'y'} $turn $spot->{'bfc_value'} $adjust" if ($spot->{'x'} == 33) and (($spot->{'y'} == 17) or ($spot->{'y'} == 16));
                    
                    next unless $adjust > (-1*$turn/150);
                    push @stat_adjust, [$adjust, $spot];
                }
                
                next unless @stat_adjust > 0;
                
                # cut down the prospective site list into a more manageable amount
                my $city_count = $civ->city_count();
                my $num_to_consider = min(0+@stat_adjust, 3 + $city_count);
                @stat_adjust = sort { $b->[0] <=> $a->[0] } @stat_adjust;
                my @final_stat_adjust = splice @stat_adjust, 0, $num_to_consider;
                my $min = $final_stat_adjust[-1][0];
                
                # now normalize their priorities by subtracting out the minimum one from each
                # (so the last one will become zero)
                my $total = 0;
                foreach my $s (@final_stat_adjust) {
                    $s->[2] = $s->[0] - $min;
                    $s->[2] = $s->[2]**2; # amplify the number
                    
                    #warn "ps2 $s->[1]{'x'} $s->[1]{'y'} $_->[2]" if ($s->[1]{'x'} == 33) and (($s->[1]{'y'} == 17) or ($s->[1]{'y'} == 16));
                    
                    $total += $s->[2];
                }
                
                # finally pick one and settle the damn thing
                my $choice;
                if ($total == 0) {
                    $choice = $final_stat_adjust[0][1];
                    $civ->add_city($settler, $choice, 1, $alloc);
                }
                else {
                    my $r = rand(1)*$total;
                    my $or = sprintf "%6.4f", $r;
                    foreach my $i (0 .. $#final_stat_adjust) {
                        $r -= $final_stat_adjust[$i][2];
                        if ($r <= 0) {
                            $choice = $final_stat_adjust[$i][1];
                            
                            my $all = join(" ", map { sprintf "%6.4f/%6.4f", $_->[0], $_->[2] } @final_stat_adjust);
                            my $prob = sprintf "prob settle %6.4f / num %d, r %s, this weight %6.4f, total weight %6.4f / all weights: <$all>", $final_stat_adjust[$i][2]/$total,  $#final_stat_adjust + 1, $or, $final_stat_adjust[$i][2], $total;
                            
                            $civ->add_city($settler, $choice, $prob, $alloc);
                            last;
                        }
                    }
                }
                
            }
        }
    }
    
    return $alloc;
}

1;