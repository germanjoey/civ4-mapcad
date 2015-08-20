package Civ4MapCad::Allocator::ModelCiv;

use strict;
use warnings;

use POSIX qw(ceil);
use List::Util qw(min max);
use Civ4MapCad::Allocator::ModelCity;

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($x, $y, $player, $tiles_per_player, $map, $alloc) = @_;
    
    my $obj = bless {
        'map' => $map,
        'player' => $player,
        'safe_dist' => sqrt($tiles_per_player/3.14159),
        'turn' => 30,
        'developed_cities' => [],
        'used_tiles' => {},
        'cities' => [],
        'prospective_zone' => {},
        'path_access' => {},
        'settlers_produced' => 0,
        'resource_access' => {},
        
        # the capital is finishing a settler when we initialize on turn 30, so really that last settler is first
        'current_queue' => ['worker', 'worker', 'settler', 'worker', 'settler', 'worker', 'settler']
    }, $class;
    
    my $capital_center = $map->get_tile($x, $y);
    
    # initialize capital
    $obj->add_city(undef, $capital_center, $alloc);
    $obj->{'starting_continent'} = $capital_center->{'continent_id'};
    
    return $obj;
}

sub strategic_adjustment {
    my ($self, $spot, $settler, $estimate_contention) = @_;
    
    # Determine a malus for settling on islands or across straights before a certain turn. (straights are pre-computed via raycasting before the simulation starts, and only matter if the city hasn't since settled nearby)
    my $overseas = 0;
    if (exists $self->{'path_access'}{$spot->get('x')}{$spot->get('y')}) {
        my $access = $self->{'path_access'}{$spot->get('x')}{$spot->get('y')};
        $overseas = 0.5 if ($spot->{'continent_id'} != $self->{'cities'}[0]{'center'}{'continent_id'}) and ($self->{'turn'} < 100);
        $overseas = 0.5 if ($access == 1) and ($self->{'turn'} < 100);
        $overseas = 2 if ($access == 2) and ($self->{'turn'} < 150);
    }
    
    my $city_count = $self->city_count();
    
    # line_dist is the straight-line distance between points, while tile-dist is the number of tiles a warrior needs to move
    # to get from one tile to another without the help of roads. The line-distance will be greater of the two; we average them here to estimate distance because diagonals can "feel" farther because cities can't overlap as easily on the diagonal.
    my $line_dist = $spot->{'distance'}{$self->{'player'}}[0];
    my $tile_dist = $spot->{'distance'}{$self->{'player'}}[1];
    my $d = ($line_dist + $tile_dist)/2;
    
    # boost effective distance early to clamp down on pink-dotting
    my $db = $d*(1 + 1/$city_count);
    
    # slowly grow a zone around our capital where we are "safe"
    my $s = max(4, 1 + 3 * int(($city_count+1)/4));
    #my $s = $self->{'safe_dist'};
    
    # now give a bonus or malus depending on how far away a city is; closer cities are rewarded
    # https://www.wolframalpha.com/input/?i=plot++%28-0.25-%28%28%28x-7%29%2Fx%29%2Fsqrt%281%2B%28%28x-7%29%2Fx%29%5E2%29%29%29%2F2+from+0+to+20
    # note that we only look at sites between 3 and 5 tiles away from any city we've currently settled, so we don't have to worry about this
    # clamining some sick site on the other side of the map
    my $dist_bonus_pre_adjust = (-0.25 - ((($db-$s)/$db)/sqrt(1+(($db-$s)/$db)**2)))/1.5;
    
    # instead of just dividing by 2, we'll make the bonus matter more at few cities and matter less at a lot of cities
    my $dist_bonus = 1.25*$dist_bonus_pre_adjust/log($city_count + 2);
    
    # now adjust to try gaining more land... after a certain number of cities, settling aggressively towards opponents will become more and more appealing
    my $comp_bonus = 1;
    $comp_bonus += sqrt($d-$s)*(log($city_count-5)-2)/20 if ($d > $s) and ($city_count > 5);
    
    # the AZZA FACTOR
    # tiles that were estimated to be contested are also valuable to claim, so lets give another bonus based on that
    # however, we don't want it to go nuts giving bonuses to 0% or 100% tiles either, so lets give the max bonus around 50% contention
    my $contention_bonus = 0;
    my $ownership = $spot->{'bfc'}->get_estimated_ownership($self->{'player'});
    if ($estimate_contention == 1) {
        my $contention = 1 - $ownership;
        # first, lets consider a contention threshold. if the area is not at least this much ours on average, then its probably too far of a reach
        # we start at thinking 0.5 is a good limit, and this decreases slowly
        my $threshold = 0.5/log($city_count + 1);
        my $ownership = $spot->{'bfc'}->get_estimated_ownership($self->{'player'});
        if ($ownership > $threshold) {
            
            # here, the contention will slowly end up matter more, until we're adding approximately $contention/2
            $contention_bonus = $contention*(1 - 1/sqrt(sqrt($city_count-5))) if $city_count > 5;
            $contention_bonus /= 8;
        }
    }
    
    # now lets consider access to resources
    my $strat_bonus = 0;
    my $def = \%Civ4MapCad::Allocator::resource_yield;
    
    if ((! exists $self->{'resource_access'}{'copper'}) and $spot->{'bfc'}->has_resource_any_ring('copper')) {
        $strat_bonus += max(1, (1/10)*(2**($self->city_count() - 2)));
    }
    
    # TODO: luxuries
    # my @resource_list = $spot->{'bfc'}->resource_list();
    # my $lux_count = 0;
    
    return $contention_bonus + $strat_bonus + $dist_bonus + $comp_bonus*$spot->{'bfc_value'} - $overseas;
}

sub city_count {
    my ($self) = @_;
    return @{ $self->{'cities'} } + 0;
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
    
    foreach my $ddx (0..10) {
        my $dx = $ddx - 5;
        foreach my $ddy (0..10) {
            my $dy = $ddy - 5;
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

# we claim territory by marking tiles within 2 of it as claimed and then also removing those tiles from our prospective settling region
sub claim_area {
    my ($self, $center, $alloc) = @_;

    # first mark the city tile as taken
    my $cx = $center->get('x');
    my $cy = $center->get('y');
    $center->{'city_available'} = 0;
    $alloc->[$cx][$cy]{$self->{'player'}} = 1;
    $self->{'prospective_zone'}{$cx}{$cy} = undef;
    
    # clear out the bfc tiles
    foreach my $tile ($center->{'bfc'}->get_all_tiles()) {
        my $x = $tile->get('x');
        my $y = $tile->get('y');
        
        if (defined $tile) {
            $tile->{'city_available'} = 0;
            $alloc->[$x][$y]{$self->{'player'}} = 1;
            $self->{'prospective_zone'}{$x}{$y} = undef;
        }
    }
    
    # now clear out the center tile and the corners
    foreach my $dx (-2, 2) {
        foreach my $dy (-2, 2) {
            my $tile = $self->{'map'}->get_tile($cx+$dx, $cy+$dy);
            if (defined $tile) {
                $tile->{'city_available'} = 0;
                $self->{'prospective_zone'}{$tile->get('x')}{$tile->get('y')} = undef;
            }
        }
    }
}

sub add_city {
    my ($self, $settler, $center, $alloc) = @_;
    
    # TODO: SHARED TILES DEALT WITH HERE
    my $blocked_tiles = {};
    
    $self->add_to_prospective_zone($center);
    $self->claim_area($center, $alloc);
    
    # TODO: take into account boat time, if necessary
    # TODO: need a map->distance_between_points function, which takes wrap into account
    # TODO: modelcity should just give its center tile as a settler
    # nOTE: need to ignore the settler for the capital city
    
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
}

sub advance_turn {
    my ($self) = @_;
    
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
    
    my $c = $self->city_count();
    if ($c > 7) {
        my $num_slackers = min(int($c/2), int( ($c-2) / (5-log($c)) ));
    
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

1;
