#!perl

use strict;
use warnings;

# perl 5.26 removed "." from @INC by default, so we've gotta re-add it.
BEGIN {
    if ($] >= 5.026) {
        use File::Spec;
        my $current_file = File::Spec->rel2abs(__FILE__);
        $current_file =~ s/\\\w+\.pl$//;
        chdir $current_file or die "Can't chdir to $current_file: $!\n";
        # safe now
        push @INC, '.';
    }
}

use lib 'lib';
use List::Util qw(min max);

use Getopt::Long;

use Civ4MapCad;
use Civ4MapCad::Map;
use Civ4MapCad::Allocator;
use Civ4MapCad::Map::Tile;
use Civ4MapCad::Dump qw(dump_framework); 
use Civ4MapCad::Object::Mask;

our $DEBUG = 0;
$Civ4MapCad::Map::Tile::DEBUG = 1;

my $iterations = 100;
my $tuning_iterations = 40;
my $to_turn = 145;
my $input_filename = 'map.CivBeyondSwordWBSave';
my $balance_config = 'def/balance.cfg';
my @heatmaps = ();
my $heatmap_options = 0;
my $mod = 'rtr 2.0.7.4';
my $from_mapcad = 0;

our $state = Civ4MapCad->new();

GetOptions ("iterations=i" => \$iterations,
            "tuning_iterations=i" => \$tuning_iterations,
            "to_turn=i" => \$to_turn,
            "mod=s" => \$mod,
            "input_filename=s" => \$input_filename,
            "balance_config=s" => \$balance_config,
            "heatmap=s" => \@heatmaps,
            "heatmap_options" => \$heatmap_options,
            "from_mapcad" => \$from_mapcad,
            "mod=s" => \$mod
            ) or $state->report_error("Error in command line arguments.\n");
@heatmaps = ('bfc_value') if @heatmaps == 0;

$SIG{__DIE__} = sub {
    my $message = shift; 
    open (my $error_log, '>>', "error.txt");
    print $error_log $message;
    close $error_log;
    $main::state->process_command('write_log');
};

if ($from_mapcad == 0) {
    open (my $error_log, '>', "error.txt") or die $!;
    open (my $output_log, '>', "output.txt") or die $!;
}

if (! -e $balance_config) {
    $state->report_error(qq[The balance config file "$balance_config" does not exist!]);
    exit -1;
}
            
our %config = Config::General->new($balance_config)->getall();

my ($base_name) = $input_filename =~ /^(.*).CivBeyondSwordWBSave$/;
            
# heatmap options
# a plus before a name means 'add_to_existing'
my %available_heatmaps = (
    'bfc_value' => sub { $_[0]->{'bfc_value'} },
    'bfc_value_ancient' => sub { $_[0]->{'original_bfc_value'} },
    'bfc_trees' => sub { $_[0]->{'trees'} },
    'bfc_river' => sub { $_[0]->{'river'} },
    'bfc_bad' => sub { $_[0]->{'bad'} },
    'bfc_food' => sub { $_[0]->{'food'} },
    'bfc_frf' => sub { $_[0]->{'frf'} },
    
    'tile_value' => sub { $_[0]->{'value'} },
    'tile_food_yield' => sub { $_[0]->{'yld'}[0] },
    'tile_hammer_yield' => sub { $_[0]->{'yld'}[1] },
    'tile_commerce_yield' => sub { $_[0]->{'yld'}[2] },
    'tile_river_adjacent' => sub { $_[0]->is_river_adjacent() },
    'tile_freshwater' => sub { $_[0]->is_fresh() },
    
    'contention' => 1,
    'congestion' => sub { $_[0]->{'congestion'} },
);

if ($heatmap_options == 1) {
    my @options = sort keys %available_heatmaps;
    $options[-1] = 'and ' . $options[-1];
    print "Heatmap options: ", join(', ', @options);
    print "\n\n";
    exit 1;
}

foreach my $hm (@heatmaps) {
    my $hmx = "$hm";
    $hmx =~ s/\+//g;
    if (! exists $available_heatmaps{$hmx}) {
        $state->report_error("Unknown heatmap option: '$hmx'. Use --help to see available heatmap options.");
        exit -1;
    }
}

$state->process_command('run_script "def/init.civ4mc"');
$state->process_command(qq[set_mod "$mod"]);
$state->clear_log();

my $base_var = "$input_filename";
$base_var =~ s/^(?:\w+\/)+//g;
$base_var =~ s/(?:\.\w+)+$//g;

print "\n    Starting balance report for '\$$base_var' with parameters:\n";
print "        input_filename: $input_filename\n";
print "        balance_config: $balance_config\n";
print "        mod: $mod\n";
print "        to turn: $to_turn\n";
print "        iterations: $iterations\n";
print "        tuning_iterations: $tuning_iterations\n";
print "        heatmaps: @heatmaps\n\n";

print "\n    Allocation algorithm parameters (see in def/balance.cfg for more details):\n";
foreach my $k (sort keys %config) {
    print "        $k: $config{$k}\n";
}

my $map = Civ4MapCad::Map->new();
my $ret = $map->import_map($input_filename);

if ($ret ne '') {
    die $ret;
}

print "\n\n    Starting land allocator. Note that this will take some time, perhaps even\n";
print "    several minutes if enough iterations are set.\n\n";
print "        Precalculating map features...\n\n";
my $alloc = Civ4MapCad::Allocator->new($map);
$alloc->allocate($tuning_iterations, $iterations, $to_turn);

print "\n    Done allocating.\n    Analyzing output...\n";
report($alloc, "$base_name.balance_report.txt");

print "    Generating debug save: $input_filename.debug\n";
$map->export_map("$input_filename.debug");

print "    Saving allocation data: $base_name.alloc\n";
my $alloc_filename = dump_alloc($alloc, "$base_name.alloc");

print "    Generating overlay view: $base_var.html\n";
$state->process_command(qq[import_group "$input_filename" => \$$base_var]);
$state->process_command(qq[debug_group \$$base_var --alloc_file "$base_name.alloc"]);
rename('debug.html',"$base_var.html");
output_heatmaps($alloc, $map, $base_var, \@heatmaps);
print "    All done!\n\n";

sub output_heatmaps {
    my ($alloc, $map, $base_name, $heatmaps) = @_;
    
    foreach my $i (0..$#$heatmaps) {
        my $hm = $heatmaps->[$i];
        print "    Creating heatmap $hm: $base_name.$hm.html\n";
        
        if ($hm =~ /contention/i) {            
            debug_overlay($alloc);
            next;
        }
        
        my $a_t_e = (($hm =~ /^\+/) and ($i != 0)) ? ' --add_to_existing' : '';
        $hm =~ s/\+//g;
        
        my $mask = create_mask_from_map($map, $available_heatmaps{$hm});
        $state->set_variable("\@$hm", 'mask', $mask);
        
        $state->process_command("debug_mask \@$hm $a_t_e");
        rename('debug.html',"$base_name.$hm.html");
    }
}

sub create_mask_from_map {
    my ($map, $func) = @_;
    
    my $width = $alloc->get_width();
    my $height = $alloc->get_height();

    my $mask = Civ4MapCad::Object::Mask->new_blank($width, $height);
    foreach my $x (0..$width-1) {
        foreach my $y (0..$height-1) {
            my $v = eval { $func->($map->{'Tiles'}[$x][$y]) };
            $mask->{'canvas'}[$x][$y] = (defined $v) ? $v : 0;
        }
    }
    return $mask;
}

sub dump_alloc {
    my ($alloc, $alloc_filename) = @_;
    
    open (my $aout, '>', $alloc_filename) or die $!;
    
    my $width = $alloc->get_width();
    my $height = $alloc->get_height();

    foreach my $x (0 .. $width-1) {
        foreach my $y (0 .. $height-1) {
            foreach my $civ (keys %{ $alloc->{'average_allocation'}[$x][$y] }) {
                printf $aout "%3d %3d %2d %6.4f\n", $x, $y, $civ, $alloc->{'average_allocation'}[$x][$y]{$civ};
            }
        }
    }
    
    close $aout;
}

sub report {
    my ($alloc, $output_filename) = @_;
    
    my %riverage;
    my %food_score;
    my %food_count;
    my %wfood_count;
    
    my %land_tile_count;
    my %coast_tile_count;
    
    my %contested_land_count;
    my %contested_coast_count;
    
    my %luxes;
    my %neighbor_contest;
    foreach my $civ (keys %{$alloc->{'avg_city_count'}}) {
        $luxes{$civ} = {
            'al' => {},
            'cl' => {}
        };
        $contested_land_count{$civ} = 0;
        $land_tile_count{$civ} = 0;
        $wfood_count{$civ} = 0;
        $food_count{$civ} = 0;
        $food_score{$civ} = 0;
        $riverage{$civ} = 0;
        $coast_tile_count{$civ} = 0;
        $contested_coast_count{$civ} = 0;
        
        foreach my $other_civ (keys %{$alloc->{'avg_city_count'}}) {
            next if $other_civ == $civ;
            $neighbor_contest{$civ}{$other_civ} = 0;
        }
    }
    
    # these are basically checkmarks
    my %access_to = (
        'stone' => {},
        'iron' => {},
        'marble' => {},
        'uranium' => {},
        'oil' => {},
        'coal' => {},
        'aluminum' => {},
        'ivory' => {},
        'copper' => {},
        'horse' => {}
    );
    
    # for these we want to find the closest to them
    my %quality_access_to = (
        'copper' => {},
        'horse' => {}
    );
    
    # collect information about tiles
    my $width = $alloc->get_width();
    my $height = $alloc->get_height();
    foreach my $x (0 .. $width-1) {
        foreach my $y (0 .. $height-1) {
            my $tile = $map->{'Tiles'}[$x][$y];
            
            my $food = 0;
            my $wfood = 0;
            if ((exists $tile->{'bonus_type'}) and ($tile->{'bonus_type'} eq 'f')) {
                $food = 1;
            }
            elsif ((exists $tile->{'bonus_type'}) and ($tile->{'bonus_type'} eq 'wf')) {
                $wfood = 1;
            }
            elsif ((exists $tile->{'FeatureType'}) and ($tile->{'FeatureType'} =~ /flood|oasis/)) {
                $wfood = 0.5;
            }
            
            foreach my $civ (keys %{ $alloc->{'average_allocation'}[$x][$y] }) {
                my $v = $alloc->{'average_allocation'}[$x][$y]{$civ};
                next unless $v > 0;
                
                $food_score{$civ} += $v*$v*($tile->{'yld'}[0]-2)*($tile->{'yld'}[0]-2) if ($food+$wfood) > 0;
                
                $food_count{$civ} += $v*$food;
                $wfood_count{$civ} += $v*$wfood;
                
                my $is_land = find_tile_category($tile);
                
                if($is_land == 0) {
                    $coast_tile_count{$civ} += $v;
                    $contested_coast_count{$civ} ++;
                }
                elsif ($is_land == 1) {
                    $land_tile_count{$civ} += $v;
                    $contested_land_count{$civ} ++;
                    
                    if ($tile->is_river_adjacent()) {
                        $riverage{$civ} += $v;
                    }
                }
                
                if ($v < 0.9) {
                    foreach my $other_civ (keys %{ $alloc->{'average_allocation'}[$x][$y] }) {
                        next if $civ == $other_civ;
                        my $w = $alloc->{'average_allocation'}[$x][$y]{$other_civ};
                        next if $w == 0;
                        
                        $neighbor_contest{$civ}{$other_civ} ++;
                    }
                }
                
                my $tile_distance = $tile->{'distance'}{$civ}[1];
                my $effective_distance = (2 - $v) * $tile_distance;    
                my $capital_tile = $alloc->{'civs'}{$civ}{'cities'}[0]{'center'};
                
                if ((exists $tile->{'BonusType'}) and (exists $tile->{'bonus_type'})) {
                    my $bonus = lc $tile->{'BonusType'};
                    $bonus =~ s/^bonus_//;
                    
                    if (exists $access_to{$bonus}) {
                        $access_to{$bonus}{$civ} = $v unless exists $access_to{$bonus}{$civ};
                        $access_to{$bonus}{$civ} = max($v, $access_to{$bonus}{$civ});
                    }
                    
                    if (exists $quality_access_to{$bonus}) {
                        if ((! exists $quality_access_to{$bonus}{$civ}) or ($quality_access_to{$bonus}{$civ}[2] > $effective_distance)) {
                            $quality_access_to{$bonus}{$civ} = [$tile, $tile_distance, $effective_distance];
                        }
                    }
                    
                    if (($tile->{'bonus_type'} eq 'al') or ($tile->{'bonus_type'} eq 'cl')) {
                        $luxes{$civ}{$tile->{'bonus_type'}}{$bonus} = [] unless exists $luxes{$civ}{$tile->{'bonus_type'}}{$bonus};
                        push @{ $luxes{$civ}{$tile->{'bonus_type'}}{$bonus} }, [$v, $tile_distance, $effective_distance]
                    }
                }
            }
        }
    }
    
    # calculate some metrics about land
    my %contest_land_average;
    my %contest_coast_average;
    
    my %ictr_found;
    my %ictr_turn_average;
    foreach my $civ (keys %{$alloc->{'avg_city_count'}}) {
        $ictr_found{$civ} = 0;
        $ictr_turn_average{$civ} = 0;
        foreach my $turn_set (@{ $alloc->{'island_settled'}{$civ} }) {
            if (@$turn_set != 0) {
                $ictr_found{$civ} += 1/$iterations;
                $ictr_turn_average{$civ} += $turn_set->[0]/$iterations;
            }
        }
        
        if ($ictr_found{$civ} != 0) {
            $ictr_turn_average{$civ} /= $ictr_found{$civ};
        }
    
        $contest_land_average{$civ} = $land_tile_count{$civ}/$contested_land_count{$civ};
        $contest_coast_average{$civ} = $coast_tile_count{$civ}/$contested_coast_count{$civ} if exists $contested_coast_count{$civ} and ($contested_coast_count{$civ} > 0);
    }
    
    my %contested_land_var;
    my %contested_coast_var;
    foreach my $x (0 .. $width-1) {
        foreach my $y (0 .. $height-1) {
            my $tile = $map->{'Tiles'}[$x][$y];
            
            my $is_land = find_tile_category($tile);
            next if $is_land == -1;
            
            foreach my $player (keys %{ $alloc->{'average_allocation'}[$x][$y] }) {
                my $v = $alloc->{'average_allocation'}[$x][$y]{$player};
                next unless $v > 0;
                
                if ($is_land == 0) {
                    $contested_coast_var{$player} += ($v - $contest_coast_average{$player})**2; 
                }
                else {
                    $contested_land_var{$player} += ($v - $contest_land_average{$player})**2; 
                }
            }
        }
    }
    
    my ($max_lux_score, $total_lux_score) = calculate_lux_score(\%luxes);
    my ($strat, $quality_strat) = calculate_strategic_access($alloc, \%access_to, \%quality_access_to);
    
    my $max_food_score = 0;
    foreach my $civ (keys %food_score) {
        my $total_tile = $land_tile_count{$civ} + $main::config{'coast_worth'}*$coast_tile_count{$civ};
        $food_score{$civ} = sqrt($food_score{$civ})/$total_tile;
        $max_food_score = $food_score{$civ} if $food_score{$civ} > $max_food_score;
    }
    $food_score{$_} /= $max_food_score foreach (keys %food_score);
    
    # tabulate an index of warnings for the map
    my %worst_civ = (
        'food' => [1, -1],
        'lux' => [1,-1],
        'quality_resource' => {},
        'missing' => {},
        'bad' => [],
    );
    
    foreach my $civ (sort {$a <=> $b} (keys %{$alloc->{'avg_city_count'}})) {
        $worst_civ{'food'} = [$food_score{$civ}, $civ] if $food_score{$civ} < $worst_civ{'food'}[0];
    
    
        if (! exists $total_lux_score->{$civ}) {
            $worst_civ{'lux'} = [0, $civ];
        }
        else {
            my $score = $total_lux_score->{$civ}{'score'}/$max_lux_score;
            $worst_civ{'lux'} = [$score, $civ] if $score < $worst_civ{'lux'}[0];
        }
            
        foreach my $bonus (keys %{ $quality_strat->{$civ} }) {
            my $score = $quality_strat->{$civ}{$bonus}{'score'};
            $worst_civ{'quality_resource'}{$bonus} = [1, -1] unless exists $worst_civ{'quality_resource'}{$bonus};
            $worst_civ{'quality_resource'}{$bonus} = [$score, $civ] if $score < $worst_civ{'quality_resource'}{$bonus}[0];
        }
        
        foreach my $type ('completely missing', 'probably unavailable') {
            foreach my $r (@{ $strat->{$type}{$civ} }) {
                $worst_civ{'missing'}{$type}{$r} = [] unless exists $worst_civ{'missing'}{$type}{$r};
                push @{ $worst_civ{'missing'}{$type}{$r} }, $civ;
            }
        }
    }
    
    #########################################################################
    # Final report!
    
    open (my $bo, '>', $output_filename) or die $!;
    open (TABLE, '>', "$output_filename.table") or die $!;
    printf TABLE "Player Name\tAvg Tiles\tAvg Land Tiles\tAvg Coast\tAvg River-Adjacent Tiles\tAvg Strong Food Tiles\tAvg Weak Food Tiles\tFood Density Score\tLuxury Score\n";
    
    print $bo "*** Balance report for $input_filename ***\n\n";
    print $bo "Simulated land up to turn $to_turn with $tuning_iterations tuning iterations and $iterations actual iterations.\n\n";
    print $bo "\n";
    print $bo "Note: relative food density scores, relative luxury scores, and relative strategic quality scores do not mean\n";
    print $bo "much by themselves, but only in comparison to the other players. For example, if one player has a luxury score of 1.0\n";
    print $bo "and another has one of 0.2, that is something that means that there's a big luxury difference between the two of them.\n\n\n";
    
    # warnings
    print $bo "** Potential warnings (things worth looking at closer):\n";
    print $bo "   Worst relative food score: $map->{'Players'}[$worst_civ{'food'}[1]]{'LeaderName'} (Player $worst_civ{'food'}[1]) with a score of $worst_civ{'food'}[0].\n";
    print $bo "   Worst relative luxury score: $map->{'Players'}[$worst_civ{'lux'}[1]]{'LeaderName'} (Player $worst_civ{'lux'}[1]) with a score of $worst_civ{'lux'}[0].\n";
    
    foreach my $r (sort keys %{ $worst_civ{'quality_resource'} }) {
        print $bo "   Worst relative $r score: $map->{'Players'}[$worst_civ{'quality_resource'}{$r}[1]]{'LeaderName'} (Player $worst_civ{'quality_resource'}{$r}[1]) with a score of $worst_civ{'quality_resource'}{$r}[0].\n";
    }
    
    print $bo "\n";
    
    my @certainty = sort keys %{ $worst_civ{'missing'}{'completely missing'} };
    if (@certainty > 0) {
        print $bo "  Civs missing resources with certainty:\n";
        foreach my $r (@certainty) {
            next if @{ $worst_civ{'missing'}{'completely missing'}{$r} } == 0;
            print $bo "    $r: ";
            foreach my $civ (@{ $worst_civ{'missing'}{'completely missing'}{$r} }) {
                my $name = $map->{'Players'}[$civ]{'LeaderName'};
                print $bo "$name ($civ) ";
            }
            print $bo "\n";
        }
        print $bo "\n";
    }
    
    my @hl = sort keys %{ $worst_civ{'missing'}{'probably unavailable'} };
        
    if (@hl > 0) {
        print $bo "  Civs missing resources with high likelihood:\n";
        foreach my $r (@hl) {
            next if @{ $worst_civ{'missing'}{'probably unavailable'}{$r} } == 0;
            print $bo "    $r: ";
            foreach my $civ (@{ $worst_civ{'missing'}{'probably unavailable'}{$r} }) {
                my $name = $map->{'Players'}[$civ]{'LeaderName'};
                print $bo "$name ($civ) ";
            }
            print $bo "\n";
        }
    }
    
    print $bo "\n\n";
    print $bo "** General Report:\n\n";
      
    # general info for each civ
    foreach my $civ (sort {$a <=> $b} (keys %{$alloc->{'avg_city_count'}})) {
        ##########################
        # General metrics
        
        my $land_std = sqrt($contested_land_var{$civ}/$contested_land_count{$civ});
        my $coast_std = 0;
        $coast_std = sqrt($contested_coast_var{$civ}/$contested_coast_count{$civ}) if $contested_coast_count{$civ} > 0;
        my $capital = $alloc->{'civs'}{$civ}{'cities'}[0]{'center'};
        my $average_value = $alloc->{'avg_city_value'}{$civ}/$alloc->{'avg_city_count'}{$civ};
        my $name = $map->{'Players'}[$civ]{'LeaderName'};
        
        my $total_tile = $land_tile_count{$civ} + $main::config{'coast_worth'}*$coast_tile_count{$civ};
        my $total_contention = $total_tile / ($contested_land_count{$civ} + $main::config{'coast_worth'}*$contested_coast_count{$civ});
        
        print $bo "For Player $civ ($name):\n";
        print $bo "    Capital at: $capital->{'x'}, $capital->{'y'}\n";
        printf $bo "    Expected number/value of cities: %5.2f / %5.3f\n", $alloc->{'avg_city_count'}{$civ}, $average_value;
        printf $bo "    Expected number of strong/weak food resources: %5.2f / %5.2f\n", $food_count{$civ}, $wfood_count{$civ};
        printf $bo "    Relative food density score: %5.3f\n", $food_score{$civ};
        print $bo "\n";
        printf $bo "    Expected number of owned live land tiles, and live land tiles touched: %6.2f / %d\n", $land_tile_count{$civ},  $contested_land_count{$civ};
        printf $bo "    Average/Stddev ownership per live land tile: %5.3f / %6.4f\n", $contest_land_average{$civ}, $land_std;
        printf $bo "    Expected number of owned coast tiles, and coast tiles touched: %6.2f / %d\n", $coast_tile_count{$civ},  $contested_coast_count{$civ};
        printf $bo "    Average/Stddev ownership per coast tile: %5.3f / %6.4f\n", $contest_coast_average{$civ}, $coast_std;
        printf $bo "    Expected number of river-adjacent land tiles: %5.2f", $riverage{$civ}; 
        print $bo "\n";
        printf $bo "    Overall tile score and contention: %6.2f / %5.3f\n", $total_tile, $total_contention;
        
        if ($ictr_found{$civ} > 0) {
            my $type = ($ictr_turn_average{$civ} >= $main::config{'astro_timing'}) ? '(post-Astro ICTR acccess)' : '(pre-Astro ICTR access)';
            printf $bo "    $name settled offshore in %4.2f%% of simulations, on average on turn %d. $type\n", $ictr_found{$civ}*100, int($ictr_turn_average{$civ});
        }
        else {
            printf $bo "    * WARNING: in all iterations, $name never once settled off of their starting continent! (no ICTR access)\n";
        }
        
        ##########################
        # Strategic resources
        
        print $bo "\n";
        print $bo "    Strategic access:\n";
        
        foreach my $bonus (keys %{ $quality_strat->{$civ} }) {
            print $bo $quality_strat->{$civ}{$bonus}{'full_desc'}, "\n";
        }
        
        print $bo "\n";
        my $any_missing_strat = 0;
        foreach my $type ('completely missing', 'probably unavailable', 'uncertain') {
            if (@{ $strat->{$type}{$civ} } == 1) {
                my $r = $strat->{$type}{$civ}[0];
                print $bo "        WARNING: Strategic access to $r is $type nearby ${name}'s start.\n";
                $any_missing_strat ++;
            }
            elsif (@{ $strat->{$type}{$civ} } > 1) {
                my $r;
                if (@{ $strat->{$type}{$civ} } > 2) {
                    $strat->{$type}{$civ}[-1] =  'and ' . $strat->{$type}{$civ}[-1] if @{ $strat->{$type}{$civ} } > 1;
                    $r = join ', ', @{ $strat->{$type}{$civ} };
                }
                else {
                    $r = "$strat->{$type}{$civ}[0] and $strat->{$type}{$civ}[1]"
                }
                print $bo "        WARNING: Access to $r is $type nearby ${name}'s start.\n";
                $any_missing_strat ++;
            }
        }
        if ($any_missing_strat == 0) {
            print $bo "    All strategic resources are fully accounted for!\n";
        }
        
        
        ##########################
        # Luxuries
        
        if (! exists $total_lux_score->{$civ}) {
            $total_lux_score->{$civ} = {
                'score' => 0,
                'full_desc' => "SEVERE WARNING: THIS CIV HAS NO ACCESS TO LUXURIES!!"
            };
        }
        
        print $bo "\n";
        printf $bo "  Relative lux score: %5.3f\n", $total_lux_score->{$civ}{'score'}/$max_lux_score;
        print $bo $total_lux_score->{$civ}{'full_desc'}, "\n";
        print $bo join("\n", map { "        ancient $_" } @{ $total_lux_score->{$civ}{'al'} });
        print $bo "\n";
        print $bo join("\n", map { "        classical $_" } @{ $total_lux_score->{$civ}{'cl'} });
        print $bo "\n";
        
        printf TABLE "%s\t%5.2f\t%5.2f\t%5.2f\t%5.2f\t%5.2f\t%5.2f\t%5.2f\t%5.3f\n", $name, $total_tile, $land_tile_count{$civ}, $coast_tile_count{$civ}, $riverage{$civ}, $food_count{$civ}, $wfood_count{$civ}, $food_score{$civ}, $total_lux_score->{$civ}{'score'}/$max_lux_score;
        
        ##########################
        # Neighbors
        
        my @dist;
        foreach my $other_player (keys %{ $capital->{'distance'} }) {
            my $d = $capital->{'distance'}{$other_player}[1];
            # next unless $capital->{'continent_id'} == $alloc->{'civs'}{$other_player}{'cities'}[0]{'center'}{'continent_id'};
            next unless (exists $neighbor_contest{$civ}{$other_player}) and $neighbor_contest{$civ}{$other_player} > 0;
            my $other_name = $map->{'Players'}[$other_player]{'LeaderName'};
            push @dist, [$d, $other_player, $other_name, $neighbor_contest{$civ}{$other_player}] if ($d != 0) and ($d < 25);
        }
        @dist = sort { $a->[0] <=> $b->[0] } @dist;
        
        print $bo "\n";
        print $bo "    Distance to nearby players' capitals: \n";
        
        my @neighbor_descs;
        foreach my $set (@dist) {
            my ($d, $other_player, $other_name, $contest) = @$set;
            push @neighbor_descs, "        $other_name (player $other_player) is $d tiles away, and contests $contest possible tiles with $name."
        }
        
        print $bo join("\n", @neighbor_descs );
        print $bo "\n\n\n";
    }
    
    if ($DEBUG == 1) {
        foreach my $civ (sort {$a <=> $b} (keys %{$alloc->{'civs'}})) {
            print $bo "\n\n*********************************\n\n";
            print $bo "DEBUG FOR $civ\n";
            print $bo "\n\n";
            $alloc->{'civs'}{$civ}->debug($bo);
            print $bo "\nCITIES for $civ\n";
            foreach my $city (@{ $alloc->{'civs'}{$civ}{'cities'} }) {
                $city->debug($bo);
            }
        }
    }
    
    close TABLE;
    close $bo;
}

sub find_tile_category {
    my ($tile) = @_;

    if($tile->is_coast()) {
        return 0;
    }
    elsif ($tile->{'PlotType'} == 3) {
        return 0 if exists $tile->{'BonusType'};
        return -1;
    }
    elsif ($tile->{'PlotType'} == 1) {
        return 1;
    }
    elsif ($tile->{'PlotType'} == 2) {
        if ($tile->{'TerrainType'} =~ /(?:snow|desert|tundra)/i) {
            if ((exists $tile->{'BonusType'}) or (exists $tile->{'FeatureType'}) or ($tile->is_fresh())) {
               return 1;
            }
            else {
                return -1;
            }
        }
        else {
           return 1;
        }
    }
    
    return -1;
}

sub calculate_lux_score {
    my ($luxes) = @_;
    
    my %optimized_lux_score;
    my $player_count = 0;
    foreach my $civ (keys %$luxes) {
        $player_count ++;
        $optimized_lux_score{$civ} = {
            'al' => [],
            'cl' => [],
        };
    }

    # calculate metrics based on luxury access
    my %owned;
    my %lux_score;
    foreach my $civ (keys %$luxes) {
        foreach my $type (keys %{ $luxes->{$civ} }) {
        
            my %max;
            my %total;
            foreach my $bonus (keys %{ $luxes->{$civ}{$type} }) {
            
                $max{$bonus} = 0;
                $total{$bonus} = 0;
                foreach my $instance (@{ $luxes->{$civ}{$type}{$bonus} }) {
                    my ($v,$d,$ed) = @$instance;
                    $total{$bonus} += $v;
                    $max{$bonus} = $v if $v > $max{$bonus};
                }
                
                $owned{$bonus} = 0 unless exists $owned{$bonus};
                $owned{$bonus} += $max{$bonus};
            }
            
            foreach my $bonus (keys %max) {
                $lux_score{$civ}{$type}{$bonus} = [$max{$bonus}, $total{$bonus}];
            }
        }
    }
    
    # condense resources found in both ancient and classical states (i.e. jungled)
    foreach my $bonus (keys %owned) {
        foreach my $civ (keys %lux_score) {
        
            # if we have an ancient resource covered and also a bare copy, which is more likely to be what we actually have?
            if ((exists $lux_score{$civ}{'al'}{$bonus}) and (exists $lux_score{$civ}{'cl'}{$bonus})) {
                my $al = $lux_score{$civ}{'al'}{$bonus};
                my $cl = $lux_score{$civ}{'cl'}{$bonus};
                
                # more likely to be classical access, count as a classical resource
                if ((($cl->[0]-0.2) > $al->[0]) and ($al->[0] < 0.7)) {
                    $cl->[1] = $al->[1] + $cl->[1];
                    delete $lux_score{$civ}{'al'}{$bonus};
                }
                else {
                    $al->[1] = $al->[1] + $cl->[1];
                    delete $lux_score{$civ}{'cl'}{$bonus};
                }
            }
        }
    }
    
    my $max_lux_score = -1;
    foreach my $civ (keys %lux_score) {
        my %count = (
            'al' => 0,
            'cl' => 0,
            'total' => 0
        );
        
        my %score = (
            'al' => 0,
            'cl' => 0
        );
        
        foreach my $type (keys %{ $lux_score{$civ} }) {
            foreach my $bonus (keys %{ $lux_score{$civ}{$type} }) {
                my $percent = $owned{$bonus}/$player_count;
                my ($max_likelihood, $total_instances) = @{ $lux_score{$civ}{$type}{$bonus} };
                next unless $max_likelihood > 0.1;
                
                my $desc = sprintf "$bonus (%d%% likehood of access; %5.3f instances obtained; owned by %5.3f%% of all players)", int(100*$max_likelihood), $total_instances, 100*$percent;
                $count{$type} += $max_likelihood;
                $count{'total'} += $max_likelihood;
                $score{$type} += $max_likelihood*($max_likelihood*(2-$percent) + max(0, $total_instances-1)*(1-$percent));
                
                push @{ $optimized_lux_score{$civ}{$type} }, $desc;
            }
        }
        
        $optimized_lux_score{$civ}{'score'} = 2*$score{'al'} + $score{'cl'};
        $max_lux_score = $optimized_lux_score{$civ}{'score'} if $optimized_lux_score{$civ}{'score'} > $max_lux_score;
        $optimized_lux_score{$civ}{'full_desc'} = sprintf '    %5.3f luxuries obtained, of which %5.3f are ancient and %5.3f are classical.', $count{'total'}, $count{'al'}, $count{'cl'};
    }
    
    return ($max_lux_score, \%optimized_lux_score);
}

sub calculate_strategic_access {
    my ($alloc, $access_to, $quality_access_to) = @_;

    # calculate availability of strategic resources
    my %strat;
    my %quality_strat;
    
    my $frf_factor = my $frf_extra_bonus = 0.33*(-0.3 + 1/log(2));
    
    foreach my $civ (keys %{$alloc->{'avg_city_count'}}) {
        $strat{'completely missing'}{$civ} = [];
        $strat{'probably unavailable'}{$civ} = [];
        $strat{'uncertain'}{$civ} = [];
        
        foreach my $bonus (keys %$access_to) {
            if ((! exists $access_to->{$bonus}{$civ}) or (0.1 > $access_to->{$bonus}{$civ})) {
                my $v = (exists $access_to->{$bonus}{$civ}) ? $access_to->{$bonus}{$civ} : 0;
                push @{ $strat{'completely missing'}{$civ} }, sprintf('%s (%d%% chance)', $bonus, int(100*$v));
            }
            elsif (0.35 > $access_to->{$bonus}{$civ}) {
                push @{ $strat{'probably unavailable'}{$civ} }, sprintf('%s (%d%% chance)', $bonus, int(100*$access_to->{$bonus}{$civ}));
            }
            elsif (0.6 > $access_to->{$bonus}{$civ}) {
                push @{ $strat{'uncertain'}{$civ} }, sprintf('%s (%d%% chance)', $bonus, int(100*$access_to->{$bonus}{$civ}));
            }
        }
        
        foreach my $bonus (keys %$quality_access_to) {
            my $tile = $quality_access_to->{$bonus}{$civ}[0];
            my $td = $quality_access_to->{$bonus}{$civ}[1];
            
            if (!defined $tile) {
                $quality_strat{$civ}{$bonus}{'score'} = 0.0;
                $quality_strat{$civ}{$bonus}{'full_desc'} = '        - ** SEVERE WARNING: important early strategic resource ' . ucfirst($bonus) . " is completely inaccessible!";
                next;
            }
            
            my $capital = $alloc->{'civs'}{$civ}{'cities'}[0]{'center'};
            my $dcx = abs($capital->{'x'} - $tile->{'x'});
            my $dcy = abs($capital->{'y'} - $tile->{'y'});
            
            if (($dcx != 2) and ($dcy != 2) and ($dcx <= 2) and ($dcy <= 2)) {
                $quality_strat{$civ}{$bonus}{'score'} = 1.0;
                $quality_strat{$civ}{$bonus}{'full_desc'} = '        - ' . ucfirst($bonus) . " has capital BFC access.";
                next;
            }

            my $is_third_ring = (max($dcx, $dcy) <= 3) ? 1 : 0;
            my $second_ring_factor = ($is_third_ring) ? 0.75 : 0.5; 
        
            my $max_value = 0;
            my $found_second_ring = 0;
            my $best_site;
            foreach my $spot ($tile->{'bfc'}->get_first_ring()) {
                next if ($spot->{'PlotType'} == 0) or ($spot->{'PlotType'} == 3);
                my $dscx = abs($capital->{'x'} - $spot->{'x'});
                my $dscy = abs($capital->{'y'} - $spot->{'y'});
                next if ($dscx <= 2) and ($dscy <= 2);
                
                my $spot_td = $spot->{'distance'}{$civ}[1];
                my $distance_penalty = 3/($spot_td+1);
                my $frf_extra_bonus = $frf_factor*$spot->{'frf'};
                my $score = ($spot->{'bfc_value'}+$frf_extra_bonus)*$distance_penalty;
                
                if ($score > $max_value) {
                    $best_site = $spot;
                    $max_value = $score;
                }
            }
            
            # if our best copper is only a second ring site, that's bad
            foreach my $spot ($tile->{'bfc'}->get_second_ring()) {
                next if ($spot->{'PlotType'} == 0) or ($spot->{'PlotType'} == 3);
                my $dscx = abs($capital->{'x'} - $spot->{'x'});
                my $dscy = abs($capital->{'y'} - $spot->{'y'});
                next if ($dscx <= 2) and ($dscy <= 2);
                
                my $spot_td = $spot->{'distance'}{$civ}[1];
                my $distance_penalty = 3/($spot_td+1);
                my $frf_extra_bonus = $frf_factor*$spot->{'frf'};
                
                # if copper is in our second ring, its only half as good!
                my $score = $second_ring_factor*($spot->{'bfc_value'}+$frf_extra_bonus)*$distance_penalty;
                
                if ($score > $max_value) {
                    $best_site = $spot;
                    $max_value = $score;
                    $found_second_ring = 1;
                }
            }
            
            $max_value = sprintf '%5.3f', $max_value;
            my $ring = ($found_second_ring) ? 'second' : 'first';
            $quality_strat{$civ}{$bonus}{'score'} = $max_value;
            $quality_strat{$civ}{$bonus}{'full_desc'} = 
                '        - ' . ucfirst($bonus) . " was found at a distance of $td from capital; its best site at $best_site->{'x'},$best_site->{'y'} has it in the\n"
              . "          $ring ring, with a relative strategic quality score of $max_value.";
        }
    }
    
    return (\%strat, \%quality_strat);
}

sub debug_overlay {
    my ($alloc) = @_;

    my $template = 'debug/debug.html.tmpl';
    my $set_index = 1;
    my $start_index = 0;
    
    my $canvas = $alloc->{'average_allocation'};
    my $maxrow = $#$canvas;
    my $maxcol = $#{ $canvas->[0] };
    
    my @cells;
    foreach my $y (reverse(0..$maxcol)) {
        my @row;
        foreach my $x (0..$maxrow) {
            my $max_value = 0;
            my $title = "x:$x, y:$y";
            
            foreach my $player (sort keys %{ $alloc->{'average_allocation'}[$x][$y] }) {
                my $value = $canvas->[$x][$y]{$player};
                $max_value = $value if $value > $max_value;
                my $name = $alloc->{'map'}{'Players'}[$player]{'LeaderName'};
                $title .= sprintf("; $name: %5.3f", $value) if $value > 0;
            }
            
            $max_value = $max_value;
            my $c = sprintf '#%02x00%02x', $max_value*255, 255-$max_value*255;
            
            my $cell = qq[<a title="$title"><img src="i/none.png" /></a>];
            push @row, qq[<td><div style="background-color: $c;">$cell</div></td>];
        }
        
        push @cells, \@row;
    }
    
    my $mask_name = 'contention';
    dump_framework($template, 'contention.html', $mask_name, $start_index, [["$set_index: " . $mask_name, [], \@cells]], '', '');
    return 1;
}
