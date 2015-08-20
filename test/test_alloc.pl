#!perl

use strict;
use warnings;

use lib 'lib';

use Config::General;

use Civ4MapCad::State;
use Civ4MapCad::Map;
use Civ4MapCad::Allocator;
use Civ4MapCad::Map::Tile;
use Civ4MapCad::Dump qw(dump_framework); 
use Civ4MapCad::Object::Mask;

$Civ4MapCad::Map::Tile::DEBUG = 1;
my $iterations = 1;
my $tuning_iterations = 1;

our $state = Civ4MapCad::State->new();
our %config = Config::General->new('def/config.cfg')->getall();

$config{'max_players'} = 0;
$config{'state'} = $state;

$SIG{'INT'} = sub { $main::config{'state'}->process_command('write_log'); exit(0) };
$SIG{__DIE__} = sub {
    my $message = shift; 
    open (my $error_log, '>>', "error.txt");
    print $error_log $message;
    close $error_log;
    $main::config{'state'}->process_command('write_log');
};

$state->process_command('run_script "def/init.civ4mc"');
$state->process_command('set_mod "rtr 2.0.7.4"');
$state->clear_log();

my $map = Civ4MapCad::Map->new();

my $filename = 'input/pb27/pb27_final_v2.CivBeyondSwordWBSave';

my $ret = $map->import_map($filename);
if ($ret ne '') {
    die $ret;
}

my $alloc = Civ4MapCad::Allocator->new($map);
$alloc->allocate($tuning_iterations, $iterations, 185, 150);

dump_overlay($alloc);
report($alloc);

my $width = $alloc->get_width();
my $height = $alloc->get_height();
my $mask = Civ4MapCad::Object::Mask->new_blank($width, $height);

foreach my $x (0..$width-1) {
    foreach my $y (0..$height-1) {
        my $v = $map->{'Tiles'}[$x][$y]->{'congestion'};
        $mask->{'canvas'}[$x][$y] = (defined $v) ? $v : 0;
    }
}

$state->set_variable('@bfc_value', 'mask', $mask);
$state->process_command('import_group "' . $filename . '" => $pb27');
$state->process_command('dump_group $pb27');
rename('dump.html','pb27.html');
$state->process_command('dump_mask @bfc_value');
rename('dump.html','pb27_bfc.html');
$map->export_map("test/test.out");

sub report {
    my ($alloc) = @_;
    
    my %food_count;
    my %wfood_count;
    my %tile_count;
    my %contested_count;
    foreach my $civ (keys %{$alloc->{'avg_city_count'}}) {
        $contested_count{$civ} = 0;
        $tile_count{$civ} = 0;
        $wfood_count{$civ} = 0;
        $food_count{$civ} = 0;
    }
    
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
            
            foreach my $player (keys %{ $alloc->{'average_allocation'}[$x][$y] }) {
                my $v = $alloc->{'average_allocation'}[$x][$y]{$player};
                $food_count{$player} += $v*$food;
                $wfood_count{$player} += $v*$wfood;
                
                next unless ($tile->{'PlotType'} != 0) and ($tile->{'PlotType'} != 3);
                
                $tile_count{$player} += $v if ($v > 0.05);
                $contested_count{$player} += 1 if ($v > 0.05);
            }
        }
    }
    
    my %contest_average;
    foreach my $civ (keys %{$alloc->{'avg_city_count'}}) {
        $contest_average{$civ} = $tile_count{$civ}/$contested_count{$civ};
    }
    
    my %contested_var;
    foreach my $x (0 .. $width-1) {
        foreach my $y (0 .. $height-1) {
            my $tile = $map->{'Tiles'}[$x][$y];
            next unless ($tile->{'PlotType'} != 0) and ($tile->{'PlotType'} != 3);
            foreach my $player (keys %{ $alloc->{'average_allocation'}[$x][$y] }) {
                my $v = $alloc->{'average_allocation'}[$x][$y]{$player};
                $contested_var{$player} = ($v - $contest_average{$player})**2; 
            }
        }
    }
    
    foreach my $civ (sort {$a <=> $b} (keys %{$alloc->{'avg_city_count'}})) {
        my $std = sqrt($contested_var{$civ}/$contested_count{$civ});
        my $capital = $alloc->{'civs'}{$civ}{'cities'}[0]{'center'};
        my $average_value = $alloc->{'avg_city_value'}{$civ}/$alloc->{'avg_city_count'}{$civ};
        my $name = $map->{'Players'}[$civ]{'LeaderName'};
        
        print "For $civ ($name):\n";
        print "  Capital at: $capital->{'x'}, $capital->{'y'}\n";
        print "  Average number/value of cities: $alloc->{'avg_city_count'}{$civ}/$average_value\n";
        print "  Average number of strong/weak food resources: $food_count{$civ}/$wfood_count{$civ}\n";
        print "  Expected number of owned tiles, and tiles captured: $tile_count{$civ} / $contested_count{$civ}\n";
        print "  Avgerage/std ownership per tile: $contest_average{$civ} / $std\n";
    }
}

sub dump_overlay {
    my ($alloc) = @_;

    my $template = 'debug/dump.html.tmpl';
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
            
            my $cell = qq[<a title="$title"><img src="debug/icons/none.png" /></a>];
            push @row, qq[<td class="tooltip"><div style="background-color: $c;">$cell</div></td>];
        }
        
        push @cells, \@row;
    }
    
    my $mask_name = 'test_alloc';
    dump_framework($template, 'alloc.html', $mask_name, $start_index, [["$set_index: " . $mask_name, [], \@cells]]);
    return 1;
}