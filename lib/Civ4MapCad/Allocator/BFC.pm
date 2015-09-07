package Civ4MapCad::Allocator::BFC;

use strict;
use warnings;

our $NUM_TILES_FULL = 6;

use List::Util qw(min max);

require Civ4MapCad::Allocator;

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($map, $city_tile) = @_;
    
    my $obj = bless {
        'center' => $city_tile,
        'reset' => 1,
        'coastal' => 0,
        'bfc_value' => 0,
        'num_tiles' => 0,
        'river_count' => 0,
        'trees_count' => 0,
        'replacement_counter' => 0,
        'first_ring_coastal' => 0,
        'tiles' => {},
        'any_food' => [],
        'resources_1st' => {},
        'resources_2nd' => {},
        'ring_1st' => [],
        'ring_2nd' => [],
        'upgrade_replacements' => [],
        'upgrades_1st' => {},
        'upgrades_2nd' => {},
        'upgraded_1st' => {},
        'upgraded_2nd' => {},
        'average_ownership' => {}
    }, $class;
    
    $obj->initialize($map);
    $obj->calc_bfc_value();
    
    return $obj;
}

# find the average ownership of a BFC, to see how contentious this spot is
sub find_expected_ownership {
    my ($self) = @_;
    
    foreach my $player (keys %{ $self->{'center'}{'contention_estimate'} }) {
        my $total_ownership = $self->{'center'}{'contention_estimate'}{$player};
        my $t = 1;
        foreach my $tile ($self->get_all_tiles()) {
            $total_ownership += $tile->{'contention_estimate'}{$player};
            $t ++;
        }
        $self->{'average_ownership'}{$player} = $total_ownership/$t;
    }
}

sub get_value {
    my ($self) = @_;
    return $self->{'bfc_value'};
}

sub get_first_ring {
    my ($self) = @_;
    return @{ $self->{'ring_1st'} };
}

sub get_second_ring {
    my ($self) = @_;
    return @{ $self->{'ring_2nd'} };
}

sub get_all_tiles {
    my ($self) = @_;
    return (@{ $self->{'ring_1st'} }, @{ $self->{'ring_2nd'} });
}

sub count_river {
    my ($self) = @_;
    return $self->{'river_count'};
}

sub count_trees {
    my ($self) = @_;
    return $self->{'trees_count'};
}

sub resource_list {
    my ($self, @resources) = @_;
    
    return ((keys %{ $self->{'resources_1st'} }), (keys %{ $self->{'resources_2nd'} }));
}

sub resource_list_1st_ring {
    my ($self, @resources) = @_;
    
    return (keys %{ $self->{'resources_1st'} });
}

sub resource_list_2nd_ring {
    my ($self, @resources) = @_;
    
    return (keys %{ $self->{'resources_2nd'} });
}

sub has_resource_1st_ring {
    my ($self, @resources) = @_;
    
    foreach my $r (@resources) {
        return 1 if exists $self->{'resources_1st'}{$r}
    }
    
    return 0;
}

sub has_resource_any_ring {
    my ($self, @resources) = @_;
    return 1 if $self->has_resource_1st_ring(@resources);

    foreach my $r (@resources) {
        return 1 if exists $self->{'resources_2nd'}{$r}
    }
    
    return 0;
}

sub get_estimated_ownership {
    my ($self, $player) = @_;
    return $self->{'average_ownership'}{$player};
}

sub reset {
    my ($self) = @_;
    
    $self->{'bfc_value'} = $self->{'original_bfc_value'};
    $self->{'replacement_counter'} = 0;
}

# here we upgrade a bfc's value based on a resource that just became available
sub upgrade_via_resource {
    my ($self, $bonus) = @_;
    
    foreach my $ring ('1st', '2nd') {
        next unless exists $self->{'upgrades_' . $ring}{$bonus};
        next if $self->{'upgraded_' . $ring}{$bonus} == 1;
        
        my $rep = $self->{'upgrade_replacements'}[$NUM_TILES_FULL - 1 - $self->{'replacement_counter'}] || 0;
        $rep = (abs($rep)*$rep/$NUM_TILES_FULL);
        
        $self->{'replacement_counter'} ++;
        $self->{'bfc_value'} += ($self->{'upgrades_' . $ring}{$bonus} - $rep);
        $self->{'upgraded_' . $ring}{$bonus} = 1;
        $self->{'reset'} = 0;
    }
}

sub initialize {
    my ($self, $map) = @_;
    
    my $cx = $self->{'center'}->get('x');
    my $cy = $self->{'center'}->get('y');
    
    # collect all the bfc tiles and bin them in 1st ring or second
    # also collect all the resource tiles for when we need to upgrade them later
    foreach my $ddx (0..4) {
        my $dx = $ddx - 2;
        foreach my $ddy (0..4) {
            my $dy = $ddy - 2;
            
            next if ($dx == 0) and ($dy == 0); # skip city tile
            next if (abs($dx) == 2) and (abs($dy) == 2); # skip corners
            
            my $x = $cx + $dx;
            my $y = $cy + $dy;
            my $tile = $map->get_tile($x, $y);
            
            #next unless $tile->{'PlotType'} != 0;
            next unless defined($tile);
            $self->{'num_tiles'} ++;
            
            $self->{'tiles'}{$dx}{$dy} = $tile;
            push @{ $tile->{'member_of'} }, $self;
            
            my $ring = '';
            if ((abs($dx) == 2) or (abs($dy) == 2)) {
                $ring = '2nd';
            }
            else {
                # mark that this site is lighthouseable
                $self->{'first_ring_coastal'} = 1 if ($tile->{'TerrainType'} eq 'TERRAIN_COAST') and ($self->{'center'}{'coastal'} == 1);
                $ring = '1st';
            }
            
            push @{$self->{'ring_' . $ring}}, $tile;
            
            if (exists $tile->{'BonusType'}) {
                my $bonus = lc $tile->{'BonusType'};
                $bonus =~ s/^bonus_//;
                
                $self->{'resources_' . $ring}{$bonus} = 1;
                
                if ((exists $tile->{'bonus_type'}) and ($tile->{'bonus_type'} =~ /f/)) {
                    push @{ $self->{'any_food'} }, $tile;
                }
            
                if (exists $tile->{'up_value'}) {
                    my $v = $tile->{'up_value'}*$tile->{'up_value'}/$NUM_TILES_FULL;
                    
                    # HACK TO MAKE JUNGLE AT IRONWORKING BULLSHIT WORK
                    if ((exists $tile->{'FeatureType'}) and ($tile->{'FeatureType'} eq 'FEATURE_JUNGLE')
                        and (($bonus =~ /horse|copper|marble|stone|fur/i)
                            or ((! exists $Civ4MapCad::Allocator::delayed{$bonus})
                            and (! exists $Civ4MapCad::Allocator::hidden{$bonus})))) {
                        $self->{'upgrades_' . $ring}{'iron'} = 0 unless exists $self->{'upgrades'}{'iron'};
                        $self->{'upgrades_' . $ring}{'iron'} += $v;
                        $self->{'upgraded_' . $ring}{'iron'} = 0;
                    }
                    else {
                        $self->{'upgrades_' . $ring}{$bonus} = 0 unless exists $self->{'upgrades'}{$bonus};
                        $self->{'upgrades_' . $ring}{$bonus} += $v;
                        $self->{'upgraded_' . $ring}{$bonus} = 0;
                    }
                }
            }
        }
    }
}

# calculate a metric that describes how good a city site is if we were to
# settle on this tile *purely* based on the tiles in its bfc
sub calc_bfc_value {
    my ($self) = @_;
    return if ($self->{'center'}{'PlotType'} == 0) or ($self->{'center'}{'PlotType'} == 3);
    
    # things that i want in a city in terms of pure output:
    
    # lets use half of a river plains sheep as our comparison value
    my $base_value = $main::config{'base_tile_comparison_value'};
    my $bv2 = $base_value**2;
    
    my $avg_value = 0;
    my @all_tiles = (@{ $self->{'ring_1st'} }, @{ $self->{'ring_2nd'} });
    
    my @all_values = sort { $b <=> $a }
                      map { $_->{'value'} } @all_tiles;
                      
    $self->{'upgrade_replacements'} = [@all_values[0..$NUM_TILES_FULL-1]];
    $avg_value += max(0, (abs($all_values[$_])*$all_values[$_]/$NUM_TILES_FULL)) foreach (0..$NUM_TILES_FULL-1);
    $avg_value /= $bv2;
    #$avg_value = sqrt($avg_value/$bv2);
    
    #   2.) productive without needing border pops - average of squares of top 3 in first ring
    my @fr_values = sort { $b <=> $a }
                     map { $_->{'value'} } @{ $self->{'ring_1st'} };
    my $fr_value = (max(0, $fr_values[0]) + max(0, $fr_values[1]) + max(0, $fr_values[2]))/3;
    $fr_value /= $base_value;
    
    #   3.) high total food
    my $food = 0;
    foreach my $tile (@all_tiles) {
        if ($tile->{'yld'}[0] > 3) {
            my $f = $tile->{'yld'}[0] - 2;
            $food += ($f*$f);
        }
    }
    $food = $food / (4*4 + 3*3 + 2*2); # a city with 6/5/4 food tiles
    
    #   4.) has first ring food
    my $frf = 0;
    foreach my $tile (@{ $self->{'ring_1st'} }) {
        $frf = $tile->{'yld'}[0] if exists($tile->{'bonus_type'}) and ($tile->{'bonus_type'} =~ /f/) and ($tile->{'yld'}[0] > $frf);
    }
    $frf = min(1.0, $frf*$frf/(5*5));
    
    #   5.) lots of trees 
    my $trees = 0;
    foreach my $tile (@all_tiles) {
        next unless exists $tile->{'FeatureType'};
        
        # camp resources can keep their forest
        next if (exists $tile->{'BonusType'}) and ($tile->{'BonusType'} =~ /^(?:deer|ivory|fur)$/i);
        $trees ++ if $tile->{'FeatureType'} eq 'FEATURE_FOREST';
    }
    $self->{'trees_count'} = $trees;
    $trees = min($main::config{'trees_max'}, $trees)*$main::config{'value_per_tree'};
    
    #   6.) lots of river nearby
    my $river = 0;
    foreach my $tile (@all_tiles) {
        $river ++ if $tile->is_river_adjacent();
    }
    $self->{'river_count'} = $river;
    $river = min($main::config{'river_max'}, $river)*$main::config{'value_per_river'}; # riverage only counts half compared to other factors
    
    # 7.) doesn't have bad tiles (jungle, coast w/o lighthouse, tundra, desert, snow)
    my $bad = 0;
    foreach my $tile (@all_tiles) {
        if ((exists $tile->{'FeatureType'}) and ($tile->{'FeatureType'} eq 'FEATURE_JUNGLE')) {
            $bad += 0.5;
        }
        
        # 
        if ($tile->{'TerrainType'} =~ /snow|desert|tundra/i) {
            $bad ++ unless ((exists $tile->{'FeatureType'}) and ($tile->{'FeatureType'} =~ /flood|oasis/i)) or (exists $tile->{'BonusType'});
            next;
        }
        
        # coast tiles without being coastal
        if ($tile->is_water() and ($self->{'first_ring_coastal'} == 0) and ($tile->{'freshwater'} == 0)) {
            $bad ++;
        }
        
        # peaks
        if ($tile->{'PlotType'} == 0) {
            $bad ++;
        }
    }
    
    $bad = min(1.25, max(0, ($bad-3)/8)); # BFC can have 3 bad tiles with no penalty
    
    my $twohp = (exists $self->{'center'}{'2h_plant'}) ? 1 : 0;
    my $fresh = $self->{'center'}->is_fresh();
    
    my $w1 = $main::config{'tile_value_weight'};
    my $w2 = $main::config{'fr_value_weight'};
    my $w3 = $main::config{'food_weight'};
    my $w4 = $main::config{'fr_food_weight'};
    my $w5 = $main::config{'trees_weight'};
    my $w6 = $main::config{'river_weight'};
    my $w7 = $main::config{'bad_weight'};
    my $w8 = $main::config{'freshwater_weight'};
    my $w9 = $main::config{'2h_plant_weight'};
    my $w = $w1 + $w2 + $w3 + $w4 + $w5 + $w6 + $w8 + $w9;
    
    $self->{'bfc_value'} = max(0, ($w1*$avg_value + $w2*$fr_value + $w3*$food + $w4*$frf + $w5*$trees + $w6*$river + $w7*$bad + $w8*$fresh + $w9*$twohp)/$w);
    $self->{'original_bfc_value'} = $self->{'bfc_value'};
    
    $self->{'center'}{'bfc_value'} = $self->{'bfc_value'};
    $self->{'center'}{'avg_value'} = $avg_value;
    $self->{'center'}{'fr_value'} = $fr_value;
    $self->{'center'}{'food'} = $food;
    $self->{'center'}{'frf'} = $frf;
    $self->{'center'}{'trees'} = $trees;
    $self->{'center'}{'river'} = $river;
    $self->{'center'}{'bad'} = "$self->{'first_ring_coastal'} / $bad";
}

1;