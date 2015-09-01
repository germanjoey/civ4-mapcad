package Civ4MapCad::Allocator::ModelCiv;

use strict;
use warnings;

use POSIX qw(ceil);
use List::Util qw(min max);
use Civ4MapCad::Allocator::ModelCity;

# this class models a civ builting settlers
sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($x, $y, $player, $map, $raycasts, $alloc) = @_;
    
    my $obj = bless {
        'raycasts' => $raycasts,
        'map' => $map,
        'player' => $player,
        'turn' => 30,
        'developed_cities' => [],
        'used_tiles' => {},
        'cities' => [],
        'prospective_zone' => {},
        'path_access' => {},
        'settlers_produced' => 0,
        'resource_access' => {},
        'city_search_widening_turn' => 115,
        
        # we build 4 workers for every 3 settlers to make expansion pace more realistic, and its assumed our little guys 
        # are enough to chop and improve tiles as cities grow into them
        # the capital is finishing a settler when we initialize on turn 30, so really that last settler is first
        'current_queue' => ['worker', 'worker', 'settler', 'worker', 'settler', 'worker', 'settler']
    }, $class;
    
    my $capital_center = $map->get_tile($x, $y);
    
    # initialize capital
    $obj->add_city(undef, $capital_center, $alloc);
    $obj->{'starting_continent'} = $capital_center->{'continent_id'};
    
    return $obj;
}

sub city_count {
    my ($self) = @_;
    return @{ $self->{'cities'} } + 0;
}

sub add_city {
    my ($self, $settler, $center, $alloc) = @_;
    
    # TODO: SHARED TILES DEALT WITH HERE
    
    $self->add_to_prospective_zone($center);
    $self->claim_area($center, $alloc);
    
    # TODO: take into account boat time, if necessary
    # TODO: need a map->distance_between_points function, which takes wrap into account
    
    # we don't make settlers walk to the site, but at the very least we'll delay the city
    # from actually doing stuff
    my $tile_dist = $center->{'distance'}{$self->{'player'}}[1];
    my $initial_delay = ceil($tile_dist/4);
    
    foreach my $tile ($center->{'bfc'}->get_all_tiles()) {
        $tile->{'shared_with'}{$self->{'player'}} ++;
    }
    
    my $num_cities = $self->city_count();
    my $new_city = Civ4MapCad::Allocator::ModelCity->new($self->{'player'}, $center, $self->{'turn'}, $num_cities + 1, $initial_delay);
    push @{ $self->{'cities'} }, $new_city;
    
    my @resources = $center->{'bfc'}->resource_list();
    $self->{'resource_access'}{$_} = 1 foreach (@resources);
    
    if ($num_cities == 0) {
        $new_city->initialize_as_capital($self->{'turn'});
    }
    
    if (! exists $self->{'island_settled'}) {
        if ($self->{'cities'}[0]{'center'}{'continent_id'} != $center->{'continent_id'}) {
            $self->{'island_settled'} = [$self->{'turn'}, $center];
        }
    }
}

sub advance_turn {
    my ($self) = @_;
    
    # on this turn, we're allowed to look further from our cities
    if ($self->{'turn'} == $self->{'city_search_widening_turn'}) {
        foreach my $city (@{ $self->{'cities'} }) {        
            $self->add_to_prospective_zone($city->{'center'});
        }
    }
    
    # process turn for each city, and collect whatever settlers they've
    # produced for, like, settling new cities
    my @new_cities_to_plant;
    foreach my $city (@{ $self->{'cities'} }) {
        my $update = $city->advance_turn();
        if (exists $update->{'finished_settler'}) {
            push @new_cities_to_plant, $city->get_center();
            $city->grow_next();
        }
        elsif (exists $update->{'finished_worker'}) {
            $city->grow_next();
        }
        
        if ($city->ready_to_build()) {
            $city->set_queue($self->{'current_queue'}[0]);
            my $to_shift = shift @{ $self->{'current_queue'} };
            push @{ $self->{'current_queue'} }, $to_shift;
        }
    }
    
    # what this models is that as your cities develop, you need to start building stuff like
    # libraries and stuff in them, and thus they stop "contributing" to the settler/worker pump
    my $c = $self->city_count();
    if ($c > $main::config{'city_slack_limit'}) {
        my $num_slackers = min(int($c/2), int( ($c-2) / (($main::config{'city_slack_limit'}-2)-log($c)) ));
    
        foreach my $i (0..($num_slackers-1)) {
            $self->{'cities'}[$i]->stop_settling();
        }
    }
    
    $self->{'settlers_produced'} += @new_cities_to_plant;
    $self->{'turn'} ++;
    
    return @new_cities_to_plant;
}

# improve city tile choices when new resources become available
sub choose_tiles_conditionally {
    my ($self, @resource_list) = @_;
    
    foreach my $city (@{ $self->{'cities'} }) {
        if ($city->has_resources(@resource_list)) {
            $city->calculate_growth_target();
            $city->choose_tiles();
        }
    }
}

# our strategy: try only to punish for bad conditions, not reward for good ones
sub strategic_adjustment {
    my ($self, $spot, $settler, $estimate_contention) = @_;
    my $bfc_value = $spot->{'bfc_value'};
    
    # tile distance is the number of moves a warrior would take to travel from this spot to our capital
    my $spot_tile_dist = $spot->{'distance'}{$self->{'player'}}[1];
    
    #################################################################################################
    # early-exit conditions
    #
    # pre-astro, we refuse to consider sites that are a significant distance away (22 tiles right now)
    # if we don't exist in the distance hash, then we're too far away to reasonably settle pre-astro
    
    if ($self->{'turn'} < (10+$main::config{'astro_timing'})) {
        return -5 unless $spot_tile_dist < 22;
    }
    
    # after astro we just try to get whatever we can, which is ok since we only consider sites within
    # 5 of one of our other already-planted cities anyways. so, we shouldn't be planting cities halfway
    # across the map.
    else {
        return $bfc_value;
    }
    
    #################################################################################################
    # setup
    #
    
    my $city_count = $self->city_count();
    
    # slowly grow a radial zone around our capital where we are "safe" to settle wherever we please. sites
    # outside of this zone get a penalty
    my $safe_zone_radius = max(3, 1 + 2*int(($city_count+1)/4));
    
    # an additional bonus for having first ring food depending on how many cities we've settled
    my $frf_extra_bonus = 0.33*(-0.3 + 1/log(1+$city_count))*$spot->{'frf'};
    $bfc_value = $frf_extra_bonus + $bfc_value;
   
    #################################################################################################
    # penalty for settling on a different continents 
    #
    # Determine a malus for settling on islands or across straights before a certain turn. (whether a
    # straight exists between two points is pre-computed via raycasting before the simulation starts,
    # and gets updated to the best possible condition as each new city is settled)
    
    my $overseas_malus = 0;
    my $access = $self->{'path_access'}{$spot->get('x')}{$spot->get('y')};
    if ($spot->{'continent_id'} != $self->{'cities'}[0]{'center'}{'continent_id'}) {
        if ($access == 1) {
            # TODO: this should rampdown more gently
            $overseas_malus = $main::config{'galley_malus'} if $self->{'turn'} < $main::config{'turn_galley_is_free'};
        }
        else {
            return -5 if $self->{'turn'} < $main::config{'astro_timing'};
        }
    }
    else {
        # TODO: this should rampdown more gently
        $overseas_malus = $main::config{'galley_malus'} if ($access == 1) and ($self->{'turn'} < $main::config{'turn_galley_is_free'});
    }
    
    #################################################################################################
    # diagonal penalty
    # 
    # sites on a diagonal will be a little bit more stretched out, in general, so a very small penalty
    # for them
    
    my $diagonal_malus = 1;
    my $spot_line_dist = $spot->{'distance'}{$self->{'player'}}[0];
    my $diagonal_diff = $spot_line_dist - $spot_tile_dist;
    $diagonal_malus = 1 - $diagonal_diff/$main::config{'diagonal_malus_factor'};
    
    #################################################################################################
    # distance penalty
    #
    # now try to see if this spot is closer to anyone elses' capital; if so, we penalize this spot a bit
    
    my $dist_malus = 1;
    my $min_dist = 0;
    foreach my $player (keys %{ $spot->{'distance'} }) {
        next if $player == $self->{'player'};
        my $dist_diff = $spot->{'distance'}{$player}[1] - $spot_tile_dist;
        $min_dist = $dist_diff if $dist_diff < $min_dist;
    }
    
    # the bigger $min_dist is, the better. if its negative, that means other players are closer to this spot than us!
    # so, we score this spot lower to be cautious, down to half value
    if ($min_dist < 0) {
        $dist_malus = max(0.5, 1 + $min_dist/$main::config{'dist_penalty_factor'});
    }
    
    # now adjust for diagonals
    
    
    #################################################################################################
    # outside safezone / contention / chokepoint penalities
    # 
    # if we're outside of the safe zone, we get another penalty depending on how far away we get
    # in general, this is a correction for simplifying our spot-searching algorithm (see 
    # add_to_prospective_zone and find_prospective_sites)
    # we also give an extra penalty to settling past chokepoints if that's beyond the safe zone
    
    my $outside_safe_malus = 0;
    my $choke_malus = 0;
    my $contention_bonus = 1;
    if ($spot_tile_dist > $safe_zone_radius) {
        my $dist_diff = $spot_tile_dist - $safe_zone_radius;
        $outside_safe_malus = -1*min(0.5, $dist_diff/10);
        $choke_malus = $self->chokepoint_consideration($spot, $safe_zone_radius);
        
        # the AZZA FACTOR
        # we don't want to rush out in the middle of nowhere, so we have to give a penalty
        # too to stop ourselves from being greedy that said, we allow ourselves to be more 
        # and more greedy for every additional city we settle
        
        if ($estimate_contention == 1) {
            my $ownership = $spot->{'bfc'}->get_estimated_ownership($self->{'player'});
            my $contention = 1 - $ownership;
            # first, lets consider a contention threshold. if the area is not at least this much ours on average, then
            # its probably too far of a reach we start at thinking 0.5 is a good limit, and this decreases slowly
            my $threshold = 0.5/log($city_count + 1);
            if ($ownership > $threshold) {
                # here, the contention will slowly end up matter more, until we're adding approximately $contention/2
                # $contention_bonus = $contention*(1 - 1/sqrt(sqrt($city_count-5))) if $city_count > 5;
                # $contention_bonus /= 8;
                # $contention_bonus = 0;
            }
            
            # however, if we're not confident/desperate we can hold this spot, we should back off
            else {
                $contention_bonus -= $contention/$main::config{'contention_penalty_factor'};
            }
        }
    }
    
    #################################################################################################
    # resource access
    # add bonuses to sites that give resources that we need
    my $strat_bonus = 0;
    my $def = \%Civ4MapCad::Allocator::resource_yield;
    
    if ((! exists $self->{'resource_access'}{'copper'}) and $spot->{'bfc'}->has_resource_any_ring('copper')) {
        $strat_bonus += min(0, (1/10)*(2**($self->city_count() - 2)));
    }
    
    # TODO: luxuries
    # my @resource_list = $spot->{'bfc'}->resource_list();
    # my $lux_count = 0;
    
    #################################################################################################
    # finale
    # add up all bonuses and maluses. some factors are ones we that affect how we badly we want the
    # tiles of a city (factor_adjust), while thers judge the site regardless of how good the tiles
    # actually are (const_adjust)
    
    my $const_adjust = $choke_malus + $strat_bonus + $outside_safe_malus +  $overseas_malus;
    my $factor_adjust = $contention_bonus*$diagonal_malus*$dist_malus;
    my $adjusted_value = $const_adjust + $factor_adjust*$bfc_value;
    
    return $adjusted_value;
}

# if: a.) congestion is high near this spot but not towards our nearest city, then this is a chokepoint. 
#     b.) if congestion is low near this city, and we're on the same continent as our nearest city, but
#         congestion is high towards the next city, we just settled past a chokepoint. that's BAD
#     c.) if congestion is high near this spot and near the other spot, and we're on the same continent,
#         this this is probably the other side of a big chokepoint. we don't want this either
#     d.) if congestion is low near this spot but high towards the prev city, and we have different
#         continent ids, then this is just an overseas city. use overseas adjustment instead
#     e.) medium congestion here and at previous - sites are probably just cramped
sub chokepoint_consideration {
    my ($self, $spot, $s) = @_;

    my @closest = $self->find_closet_cities_to_spot($spot);
    return 0 if @closest == 0;
    
    my @ccoords = map {"($_->{'center'}{'x'},$_->{'center'}{'y'})"} @closest;
    my $spot_congestion = $spot->{'congestion'};
    
    # consider each path from all cities closest to the potential spot 
    # and see if they cross any high congestion areas
    my @paths;
    foreach my $city (@closest) {
        my $sx = $spot->get('x');
        my $sy = $spot->get('y');
    
        my $dx = $sx - $city->{'center'}->get('x');
        my $dy = $sy - $city->{'center'}->get('y');
        my $path = $self->{'raycasts'}{$dx}{$dy};
        
        my $max_path_congestion = -1;
        for my $i (1..$#$path) {
            my $tile = $self->{'map'}->get_tile($sx - $path->[$i][0], $sy - $path->[$i][1]);
            $max_path_congestion = $tile->{'congestion'} if $tile->{'congestion'} > $max_path_congestion;
        }
        
        next unless ($spot_congestion > 0.2) or ($max_path_congestion > 0.25);

        # compare the spot to the peak congesiton along the path; positive numbers indicate this spot is a chokepoint
        my $congestion_peak_diff = $spot_congestion - $max_path_congestion - 0.05;
        
        # so if this spot is higher than anything along the path, good bet it is a chokepoint. # but how much of one?
        if ($congestion_peak_diff > 0) {
        
            # major chokepoint - priority settle
            if ((($congestion_peak_diff > 0.15) and ($spot_congestion > 0.4)) or ($congestion_peak_diff > 0.25)) {
                #push @paths, $congestion_peak_diff;
            }
            
            # medium chokepoint - desireable
            elsif ((($congestion_peak_diff > 0.10) and ($spot_congestion > 0.3)) or ($congestion_peak_diff > 0.20)) {
                #push @paths, (0.5 + congestion_peak_diff/0.25)*$congestion_peak_diff;
            }
        }
        
        # definite danger zone
        elsif ($congestion_peak_diff < -0.25) {
            push @paths, 1.5*$congestion_peak_diff;
        }
        
        # moderate danger zone
        elsif ($congestion_peak_diff < -0.15) {
            push @paths, (0.5 + (-0.15-$congestion_peak_diff)/0.1)*$congestion_peak_diff;
        }
        
        # everything else is just an "ordinary" congestion pattern
        
    }
    
    return 0 if @paths == 0;
    return min(@paths);
}

# find all cities closest to the spot, including cities that are equi-distant
sub find_closet_cities_to_spot {
    my ($self, $spot) = @_;
    my $min_d = 1000;
    my @closest;
    foreach my $city (@{ $self->{'cities'} }) {
        next if $spot->{'continent_id'} != $city->{'center'}{'continent_id'};
        my $d = $self->{'map'}->find_tile_distance_between_coords($spot->get('x'), $spot->get('y'), $city->{'center'}->get('x'), $city->{'center'}->get('y'));
        if ($d < $min_d) {
            $min_d = $d;
            @closest = ($city);
        }
        elsif ($d == $min_d) {
            push @closest, $city;
        }
    }
    return @closest;
}

# filter out sites that are not acceptable because some other civ has claimed them
sub find_prospective_sites {
    my ($self) = @_;
    
    # TODO: should where the settler spawns be considered here?
    
    my @sites;
    foreach my $x (keys %{ $self->{'prospective_zone'} }) {
        foreach my $y (keys %{ $self->{'prospective_zone'}{$x} }) {
            my $tile = $self->{'prospective_zone'}{$x}{$y};
            next unless defined $tile;
            next unless $tile->{'city_available'} == 1;
            push @sites, $tile;
        }
    }
    
    @sites = sort { $b->{'bfc_value'} <=> $a->{'bfc_value'} } @sites;
    return \@sites;
}

# the "prospective zone" is a region 3-5 tiles from all our currently settled cities
sub add_to_prospective_zone {
    my ($self, $new_center) = @_;
    
    my $cx = $new_center->get('x');
    my $cy = $new_center->get('y');
    
    my $range = ($self->{'turn'} < $self->{'city_search_widening_turn'}) ? 4 : 5;
    
    foreach my $ddx (0..(2*$range)) {
        my $dx = $ddx - $range;
        foreach my $ddy (0..(2*$range)) {
            my $dy = $ddy - $range;
            next if (abs($dx) <= 2) and (abs($dy) <= 2);
            
            my $tile = $self->{'map'}->get_tile($cx+$dx, $cy+$dy);
            next unless defined $tile;
            
            my $x = $tile->get('x');
            my $y = $tile->get('y');
            
            next unless $tile->is_land();
            next unless $tile->{'city_available'} == 1;
            next unless $tile->{'PlotType'} != 0;
            
            if (! exists $self->{'prospective_zone'}{$x}{$y}) {
                $self->{'prospective_zone'}{$x}{$y} = $tile;
            }
            
            # now try to see if we have better access to the tile
            # access = 2 if over ocean, 1 if over coast, 0 if over land.
            # access can only be upgraded, never downgraded
            
            next if exists($self->{'path_access'}{$x}{$y}) and ($self->{'path_access'}{$x}{$y} == 0);
            my $type = (exists $self->{'path_access'}{$x}{$y}) ? $self->{'path_access'}{$x}{$y} : 3;
            $type = min($type, $new_center->{'access'}{$x}{$x}) if exists $new_center->{'access'}{$x}{$x};
            foreach my $rtile ($new_center->{'bfc'}->get_all_tiles()) {
                next unless $rtile->is_land() and ($rtile->{'PlotType'} != 0);
                next unless exists $rtile->{'access'}{$x}{$y};
                $type = min($type, $rtile->{'access'}{$x}{$y}) if exists $rtile->{'access'}{$x}{$y};
            }
            
            $self->{'path_access'}{$x}{$y} = $type;
        }
    }
}

# we claim territory by marking tiles within 2 of it as claimed and then also removing
# those tiles from our prospective settling region
sub claim_area {
    my ($self, $center, $alloc) = @_;

    # first mark the city tile as taken
    my $cx = $center->get('x');
    my $cy = $center->get('y');
    $center->{'city_available'} = 0;
    $alloc->[$cx][$cy]{$self->{'player'}} = 1;
    $self->{'prospective_zone'}{$cx}{$cy} = undef;
    
    # mark out the bfc tiles
    foreach my $tile ($center->{'bfc'}->get_all_tiles()) {
        my $x = $tile->get('x');
        my $y = $tile->get('y');
        
        if (defined $tile) {
            $alloc->[$x][$y]{$self->{'player'}} = 1;
            if ($tile->is_land()) {
                next unless $tile->{'continent_id'} == $center->{'continent_id'};
            }
        
            $tile->{'city_available'} = 0;
            $self->{'prospective_zone'}{$x}{$y} = undef;
        }
    }
    
    # finally claim the corners
    foreach my $dx (-2, 2) {
        foreach my $dy (-2, 2) {
            my $tile = $self->{'map'}->get_tile($cx+$dx, $cy+$dy);
            next unless $tile->{'continent_id'} == $center->{'continent_id'};
            if (defined $tile) {
                $tile->{'city_available'} = 0;
                $self->{'prospective_zone'}{$tile->get('x')}{$tile->get('y')} = undef;
            }
        }
    }
}

1;
