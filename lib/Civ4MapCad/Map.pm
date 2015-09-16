package Civ4MapCad::Map;

use strict;
use warnings;

use List::Util qw(min max);

use Civ4MapCad::Rotator qw(rotate_grid);
use Civ4MapCad::Util qw(write_block_data deepcopy);

our @fields = qw(TeamID RevealMap);
our %field_names;
@field_names{@fields} = (1) x @fields;

use Civ4MapCad::Map::Game;
use Civ4MapCad::Map::Team;
use Civ4MapCad::Map::Player;
use Civ4MapCad::Map::MapInfo;
use Civ4MapCad::Map::Tile;
use Civ4MapCad::Map::Sign;

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    
    my $obj = {
        'freshwater_marked' => 0,
        'coast_fixed' => 0,
        'Game' => '',
        'Teams' => {},
        'MapInfo' => '',
        'Players' => [],
        'Tiles' => [], # 2d array
        'Signs' => [],
    };
    
    return bless $obj, $class;
}

sub new_default {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($width, $height) = @_;
    
    my $obj = {
        'freshwater_marked' => 0,
        'coast_fixed' => 0,
        'Version' => 'Version=11',
        'Game' => '',
        'Teams' => {},
        'MapInfo' => '',
        'Players' => [],
        'Tiles' => [], # 2d array
        'Signs' => [],
    };
    $obj = bless $obj, $class;
    
    $obj->default($width, $height);
    return $obj;
}

sub get_size {
    my ($self, $size) = @_;
    return $self->{'MapInfo'}->get('world size');
}

sub get_speed {
    my ($self, $speed) = @_;
    return $self->{'Game'}->get('Speed');
}

sub get_era {
    my ($self, $era) = @_;
    return $self->{'Game'}->get('Era');
}

sub set_size {
    my ($self, $size) = @_;
    $self->{'MapInfo'}->set('world size', $size);
}

sub set_speed {
    my ($self, $speed) = @_;
    $self->{'Game'}->set('Speed', $speed);
}

sub set_era {
    my ($self, $era) = @_;
    $self->{'Game'}->set('Era', $era);
}

# TODO: set up a unified interface?
sub info {
    my ($self, $field) = @_;
    return $self->{'MapInfo'}->get($field);
}

sub default {
    my ($self, $width, $height) = @_;
    
    $self->{'Game'} = Civ4MapCad::Map::Game->new_default();
    $self->{'MapInfo'} = Civ4MapCad::Map::MapInfo->new_default($width, $height);
    
    foreach my $i (0..$main::state->{'config'}{'max_players'}-1) {
        my $team = Civ4MapCad::Map::Team->new_default($i);
        $self->{'Teams'}{$i} = $team;
        
        my $player = Civ4MapCad::Map::Player->new_default($i);
        push @{$self->{'Players'}}, $player;
    }
    
    foreach my $x (0..$width-1) {
        foreach my $y (0..$height-1) {
            $self->{'Tiles'}[$x][$y] = Civ4MapCad::Map::Tile->new_default($x, $y);
        }
    }
    
    $self->{'freshwater_marked'} = 0;
    $self->{'coast_fixed'} = 0;
}

sub clear {
    my ($self) = @_;
    
    $self->{'Signs'} = [];
    $self->{'Game'}->clear();
    $self->{'MapInfo'}->clear();
    
    foreach my $team ($self->get_teams()) {
        $team->clear();
        #delete $self->{'Teams'}{$team};
    }
    
    foreach my $i (0..$#{ $self->{'Players'} }) {
        my $player = $self->{'Players'}[$i];
        $player->clear();
        $player->set('Team', $i);
    }
    
    $self->clear_map();
}

sub clear_map {
    my ($self) = @_;

    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            $self->{'Tiles'}[$x][$y]->clear();
            $self->{'Tiles'}[$x][$y]->default($x, $y);
        }
    }
    
    $self->{'freshwater_marked'} = 0;
    $self->{'coast_fixed'} = 0;
}

sub expand_dim {
    my ($self, $new_width, $new_height) = @_;
    
    my $current_width = $self->info('grid width');
    my $current_height = $self->info('grid height');
    
    my $width = max($new_width, $current_width);
    my $height = max($new_height, $current_height);
    
    $self->{'MapInfo'}->set('grid width', $width);
    $self->{'MapInfo'}->set('grid height', $height);
    $self->{'MapInfo'}->set('num plots written', $width*$height);
    
    foreach my $x (0..$width-1) {
        $self->{'Tiles'}[$x] = [] unless defined $self->{'Tiles'}[$x];
        foreach my $y (0..$height-1) {
            $self->{'Tiles'}[$x][$y] = Civ4MapCad::Map::Tile->new_default($x, $y)
                unless defined $self->{'Tiles'}[$x][$y];
        }
    }
}

sub find_line_distance_between_coords {
    my ($self, $width, $height, $wrapsX, $wrapsY, $from_x, $from_y, $to_x, $to_y) = @_;
    
    my $dx; my $dy;
    
    if (($wrapsX == 1) and ($wrapsY == 1)) {
        $dx = abs($from_x - $to_x);
        $dx = min($width - $dx, $dx);
        
        $dy = abs($from_y - $to_y);
        $dy = min($height - $dy, $dy);
        
    }
    elsif ($wrapsX == 1) {
        $dx = abs($from_x - $to_x);
        $dx = min($width - $dx, $dx);
        $dy = abs($from_y - $to_y);
    }
    elsif ($wrapsY == 1) {
        $dy = abs($from_y - $to_y);
        $dy = min($height - $dy, $dy);
        $dx = abs($from_x - $to_x);
    }
    else {
        $dx = abs($from_x - $to_x);
        $dy = abs($from_y - $to_y);
    }
    
    return sqrt($dx*$dx + $dy*$dy);
    
}

# width, height, wrapsX, and wrapsY are all prefetched because the profiler found that the
# calls to their accessor methods were taking an insane amount of time
sub find_tile_distance_between_coords {
    my ($self, $width, $height, $wrapsX, $wrapsY, $from_x, $from_y, $to_x, $to_y) = @_;
    
    if (($wrapsX == 1) and ($wrapsY == 1)) {
        my $dx = abs($from_x - $to_x);
        $dx = min($width - $dx, $dx);
        
        my $dy = abs($from_y - $to_y);
        $dy = min($height - $dy, $dy);
        
        return max($dx, $dy);
    }
    elsif ($wrapsX == 1) {
        my $dx = abs($from_x - $to_x);
        $dx = min($width - $dx, $dx);
        return max($dx, abs($from_y - $to_y));
    }
    elsif ($wrapsY == 1) {
        my $dy = abs($from_y - $to_y);
        $dy = min($height - $dy, $dy);
        return max(abs($from_x - $to_x), $dy);
    }
    
    return max(abs($from_x - $to_x), abs($from_y - $to_y));
}

sub wrapsX {
    my ($self) = @_;
    return ((defined($self->info('wrap X')) and ($self->info('wrap X') eq '1')) ? 1 : 0);
}

sub wrapsY {
    my ($self) = @_;
    return ((defined($self->info('wrap Y')) and ($self->info('wrap Y') eq '1')) ? 1 : 0);
}

sub set_wrapX {
    my ($self, $value) = @_;
    $self->{'MapInfo'}->set('wrap X', $value);
}

sub set_wrapY {
    my ($self, $value) = @_;
    $self->{'MapInfo'}->set('wrap Y', $value);
}

sub overwrite_tiles {
    my ($self, $map, $offsetX, $offsetY) = @_;
    
    my $width = $map->info('grid width');
    my $height = $map->info('grid height');
    
    for my $x (0..$width-1) {
        for my $y (0..$height-1) {
            if (! $map->{'Tiles'}[$x][$y]->is_blank()) {
                my $ax = $x + $offsetX;
                my $ay = $y + $offsetY;
            
                next if (($ax >= $width) or ($ax < 0)) and (!$self->wrapsX());
                next if (($ay >= $height) or ($ay < 0)) and (!$self->wrapsY());
            
                my $tx = ($ax >= $width) ? ($ax - $width) : (($ax < 0) ? ($ax + $width) : $ax);
                my $ty = ($ay >= $height) ? ($ay - $height) : (($ay < 0) ? ($ay + $height) : $ay);
            
                $self->{'Tiles'}[$tx][$ty] = deepcopy($map->{'Tiles'}[$x][$y]);
                $self->{'Tiles'}[$tx][$ty]->set('x', $tx);
                $self->{'Tiles'}[$tx][$ty]->set('y', $ty);
            }
        }
    }
}

sub add_player {
    my ($self, $fh) = @_;
    
    my $player = Civ4MapCad::Map::Player->new();
    $player->parse($fh);
    push @{ $self->{'Players'} }, $player;
}

sub get_players {
    my ($self, $fh) = @_;
    return @{$self->{'Players'}};
}

sub add_team {
    my ($self, $fh) = @_;
    
    my $team = Civ4MapCad::Map::Team->new();
    $team->parse($fh);
    my $id = $team->get('TeamID');
    warn "* WARNING: Team $id already exists!" if exists $self->{'Teams'}{$id};
    
    $self->{'Teams'}{$id} = $team;
}

sub get_teams {
    my ($self, $fh) = @_;
    return sort { $a->get('TeamID') <=> $b->get('TeamID') } (values %{$self->{'Teams'}});
}

sub add_sign {
    my ($self, $fh) = @_;
    
    my $sign = Civ4MapCad::Map::Sign->new();
    $sign->parse($fh);
    push @{$self->{'Signs'}}, $sign;
}

sub add_tile {
    my ($self, $fh, $strip_nonsettlers) = @_;
    
    my $tile = Civ4MapCad::Map::Tile->new;
    $tile->parse($fh, $strip_nonsettlers);
    
    my $x = $tile->get('x');
    my $y = $tile->get('y');
    
    $self->{'Tiles'}[$x] = [] unless defined $self->{'Tiles'}[$x];
    $self->{'Tiles'}[$x][$y] = $tile;
}

sub fill_tile {
    my ($self, $x, $y) = @_;
    $self->{'Tiles'}[$x][$y]->fill();
}

sub delete_tile {
    my ($self, $x, $y) = @_;
    $self->{'Tiles'}[$x][$y] = Civ4MapCad::Map::Tile->new_default($x, $y);
}

sub set_game {
    my ($self, $fh) = @_;
    $self->{'Game'} = Civ4MapCad::Map::Game->new;
    $self->{'Game'}->parse($fh);
}

sub set_map_info {
    my ($self, $fh) = @_;
    $self->{'MapInfo'} = Civ4MapCad::Map::MapInfo->new;
    $self->{'MapInfo'}->parse($fh);
}

sub add_sign_to_coord {
    my ($self, $x, $y, $caption) = @_;
    
    my $sign = Civ4MapCad::Map::Sign->new();
    $sign->set('plotX', $x);
    $sign->set('plotY', $y);
    $sign->set('caption', $caption);
    $sign->set('playerType', '-1');
    
    push @{$self->{'Signs'}}, $sign;
}

sub import_map {
    my ($self, $filename, $strip_nonsettlers) = @_;
    
    open (my $fh, $filename) or return "$!";
    $self->{'Version'} = <$fh>;
    chomp $self->{'Version'};
    
    while (1) {
        my $line = <$fh>;
        last unless defined $line;
        
        next if $line !~ /\w/;
        next if $line =~ /^\s*#/;
        chomp $line;
        $line =~ s/^\s*//;
        $line =~ s/\s*$//;
        
        if ($line =~ /BeginGame/) {
            $self->set_game($fh);
        }
        elsif ($line =~ /BeginTeam/) {
            $self->add_team($fh);
        }
        elsif ($line =~ /BeginPlayer/) {
            $self->add_player($fh, $strip_nonsettlers);
        }
        elsif ($line =~ /BeginMap/) {
            $self->set_map_info($fh);
        }
        elsif ($line =~ /BeginPlot/) {
            $self->add_tile($fh);
        }
        elsif ($line =~ /BeginSign/) {
            $self->add_sign($fh);
        }
        else {
            return "Unidentified block found when importing: '$line'";
        }
    }
    
    my $max_players = @{ $self->{'Players'} };
    if ($max_players != $main::state->{'config'}{'max_players'}) {
        $main::state->report_warning("Converting map '$filename' from $max_players to $main::state->{'config'}{'max_players'} players. Set 'mod' in def/config.cfg or use the 'set_mod' command to prevent automatic conversion on import.", 1);
        $self->set_max_num_players($main::state->{'config'}{'max_players'});
    }
    
    close $fh;
    $self->{'coast_fixed'} = 0;
    return '';
}

sub export_map {
    my ($self, $filename) = @_;
    
    open (my $fh, '>', $filename) or die $!;
    
    print $fh $self->{'Version'}, "\n";
    $self->{'Game'}->write($fh);
    
    foreach my $team ($self->get_teams()) {
        $team->write($fh);
    }
    
    foreach my $player ($self->get_players()) {
        $player->write($fh);
    }
    
    $self->{'MapInfo'}->set('num signs written', @{$self->{'Signs'}}+0);
    $self->{'MapInfo'}->write($fh);
    print $fh "\n### Plot Info ###\n";

    foreach my $xv (@{ $self->{'Tiles'} }) {
        foreach my $tile (@$xv) {
            $tile->write($fh);
        }
    }
    
    if (@{$self->{'Signs'}} > 0) {
        print $fh "\n### Sign Info ###\n";
    }
    foreach my $sign (@{$self->{'Signs'}}) {
        $sign->write($fh);
    }
}

sub find_starts {
    my ($self) = @_;

    my @starts;
    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            if ($self->{'Tiles'}[$x][$y]->has_settler()) {
                push @starts, $self->{'Tiles'}[$x][$y]->get_starts();
            }
        }
    }
    
    return \@starts;
}

sub reassign_start_at {
    my ($self, $x, $y, $old, $new) = @_;

    if ($self->{'Tiles'}[$x][$y]->has_settler()) {
        $self->{'Tiles'}[$x][$y]->reassign_starts($old, $new);
        $self->reassign_player($old, $new);
    }
    
    return 1;
}

# TODO: these need to reassign player/team
sub reassign_start {
    my ($self, $old, $new) = @_;

    my @starts;
    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            if ($self->{'Tiles'}[$x][$y]->has_settler()) {
                $self->{'Tiles'}[$x][$y]->reassign_starts($old, $new);
                $self->reassign_player($old, $new);
            }
            
            $self->{'Tiles'}[$x][$y]->reassign_reveals($old, $new);
        }
    }
    
    return 1;
}

sub strip_nonsettlers {
    my ($self) = @_;

    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            $self->{'Tiles'}[$x][$y]->strip_nonsettlers();
        }
    }
    
    return 1;
}

sub strip_all_units {
    my ($self) = @_;

    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            $self->{'Tiles'}[$x][$y]->strip_all_units();
        }
    }
    
    return 1;
}

sub add_scouts_to_settlers {
    my ($self) = @_;

    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            $self->{'Tiles'}[$x][$y]->add_scout_if_settler();
        }
    }
    
    return 1;
}

# accessor methods accesses optimized out
sub get_tile {
    my ($self, $x, $y) = @_;
    
    my $ux = $x;
    my $uy = $y;
    
    if ($x > $#{ $self->{'Tiles'} }) {
        return unless $self->{'MapInfo'}{'wrap X'};
        my $oldX = $ux;
        $ux = $ux - $self->{'MapInfo'}{'grid width'};
    }
    elsif ($x < 0) {
        return unless $self->{'MapInfo'}{'wrap X'};
        my $oldX = $ux;
        $ux = $ux + $self->{'MapInfo'}{'grid width'};
    }
    
    if ($y > $#{ $self->{'Tiles'}[$ux] }) {
        return unless $self->{'MapInfo'}{'wrap Y'};
        my $oldY = $uy;
        $uy = $uy - $self->{'MapInfo'}{'grid height'};
    }
    elsif ($y < 0) {
        return unless $self->{'MapInfo'}{'wrap Y'};
        my $oldY = $uy;
        $uy = $uy + $self->{'MapInfo'}{'grid height'};
    }
    
    return $self->{'Tiles'}[$ux][$uy];
}

sub add_dummy_start {
    my ($self) = @_;
    
    my $player = $self->first_unused_player();
    $self->{'Tiles'}[0][0]->set('TerrainType', 'TERRAIN_GRASS');
    $self->{'Tiles'}[0][0]->set('PlotType', '2');
    
    my $unit = Civ4MapCad::Map::Unit->new();
    $unit->set('UnitType', 'UNIT_SETTLER');
    $unit->set('UnitOwner', $player);
    $unit->set('Damage', '0');
    $unit->set('Level', '1');
    $unit->set('Experience', '0');
    $unit->set('FacingDirection', '4');
    $unit->set('UnitAIType', 'UNITAI_SETTLE');
    $self->{'Tiles'}[0][0]->add_unit($unit);
    
    $self->{'Players'}[$player] = Civ4MapCad::Map::Player->new_default($player);
    $self->{'Players'}[$player]->set('LeaderType', 'LEADER_TOKUGAWA');
    $self->{'Players'}[$player]->set('LeaderName', 'DUMMY');
    $self->{'Players'}[$player]->set('CivDesc', 'DUMMY');
    $self->{'Players'}[$player]->set('CivShortDesc', 'DUMMY');
    $self->{'Players'}[$player]->set('CivAdjective', 'DUMMY');
    $self->{'Players'}[$player]->set('FlagDecal', 'Art/Interface/TeamColor/FlagDECAL_EyeOfRa.dds');
    $self->{'Players'}[$player]->set('WhiteFlag', '0');
    $self->{'Players'}[$player]->set('Color', 'PLAYERCOLOR_DARK_PINK');
    $self->{'Players'}[$player]->set('ArtStyle', 'ARTSTYLE_MIDDLE_EAST');
    $self->{'Players'}[$player]->set('PlayableCiv', '0');
    $self->{'Players'}[$player]->set('CivType', 'CIVILIZATION_JAPAN');
    $self->{'Players'}[$player]->set('MinorNationStatus', '0');
    $self->{'Players'}[$player]->set('StartingGold', '0');
    $self->{'Players'}[$player]->set('StartingX', '0');
    $self->{'Players'}[$player]->set('StartingY', '0');
    $self->{'Players'}[$player]->set('StateReligion', '');
    $self->{'Players'}[$player]->set('StartingEra', 'ERA_ANCIENT');
    $self->{'Players'}[$player]->set('RandomStartLocation', 'false');
    $self->{'Players'}[$player]->set('Handicap', 'HANDICAP_MONARCH');
    $self->{'Players'}[$player]->add_civics('CivicOption=CIVICOPTION_GOVERNMENT, Civic=CIVIC_DESPOTISM');
    $self->{'Players'}[$player]->add_civics('CivicOption=CIVICOPTION_LEGAL, Civic=CIVICOPTION_LABOR');
    $self->{'Players'}[$player]->add_civics('CivicOption=CIVICOPTION_LABOR, Civic=CIVICOPTION_ECONOMY');
    $self->{'Players'}[$player]->add_civics('CivicOption=CIVICOPTION_ECONOMY, Civic=CIVIC_DECENTRALIZATION');
    $self->{'Players'}[$player]->add_civics('CivicOption=CIVICOPTION_RELIGION, Civic=CIVIC_PAGANISM');
    
    $self->{'Teams'}{$player}->add_contact($player);
}

sub num_players {
    my ($self) = @_;
    
    my $count = 0;
    foreach my $player (@{ $self->{'Players'} }) {
        if ($player->is_active()) {
            $count ++;
        }
    }
    
    return $count;
}


sub first_unused_player {
    my ($self) = @_;
    
    foreach my $i (0 .. $#{ $self->{'Players'}}) {
        if (! $self->{'Players'}[$i]->is_active()) {
            return $i;
        }
    }
    
    return -1;
}

sub next_used_player {
    my ($self) = @_;
    
    my $first = $self->first_unused_player();
    return -1 if $first == -1; # all player slots are used;
    
    foreach my $i ($first .. $#{ $self->{'Players'} }) {
        if ($self->{'Players'}[$i]->is_active()) {
            return $i;
        }
    }
    
    return -1;
}

sub reduce_players {
    my ($self) = @_;
    
    my $i = 0;
    while (1) {
        my $first_unused = $self->first_unused_player();
        my $next_used = $self->next_used_player();
        $i ++;
        
        last if ($first_unused == -1) or ($next_used == -1);
        $self->reassign_player($next_used, $first_unused);
    }
}

sub reassign_player {
    my ($self, $from, $to) = @_;
    
    $self->{'Players'}[$to] = deepcopy($self->{'Players'}[$from]);
    $self->{'Players'}[$from]->clear();
    $self->{'Players'}[$from]->default($from);
    
    my $teamcount = 0;
    foreach my $i (0 .. $#{ $self->{'Players'} }) {
        warn "NO TEAM <$from i $i />" unless defined($self->{'Players'}[$i]{'Team'});
        warn "NO TEAM <$from t $to/>" unless defined($self->{'Players'}[$to]{'Team'});
    
        $teamcount ++ if $self->{'Players'}[$i]->get('Team') eq $self->{'Players'}[$to]->get('Team');
    }
    
    # teamcount will be 2 because both to and from will have the team value at this point
    if ($teamcount == 2) {
        $self->{'Teams'}{$to} = deepcopy($self->{'Teams'}{$from});
        $self->{'Teams'}{$to}->set('TeamID', $to);
        $self->{'Teams'}{$to}->set_contact($to);
        $self->{'Players'}[$to]->set('Team', $to);
        
        $self->{'Teams'}{$from}->clear();
        $self->{'Teams'}{$from}->default($from);
    }
    
    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            $self->{'Tiles'}[$x][$y]->reassign_units($from, $to);
            $self->{'Tiles'}[$x][$y]->reassign_reveals($from, $to);
        }
    }
}

sub get_player_data {
    my ($self, $owner_id) = @_;
    
    return ($self->{'Players'}[$owner_id], $self->{'Teams'}{$owner_id});
}

sub set_player_from_other {
    my ($self, $owner_id, $player, $team) = @_;
    
    $self->{'Players'}[$owner_id] = $player;
    $self->{'Players'}[$owner_id]->set('Team', $owner_id);
    
    $self->{'Teams'}{$owner_id} = $team;
}

sub strip_hidden_strategic {
    my ($self) = @_;

    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            $self->{'Tiles'}[$x][$y]->strip_hidden_strategic();
        }
    }
    
    return 1;
}

sub set_difficulty {
    my ($self, $level) = @_;
    
    my $total = 0;
    foreach my $player (@{ $self->{'Players'} }) {
        if (($player->get('CivType') ne 'NONE') and ($player->get('Handicap') ne $level)) {
            $player->set('Handicap', $level);
            $total ++;
        }
    }
    return $total;
}

sub strip_victories {
    my ($self) = @_;
    $self->{'Game'}->strip_victories();
}

sub set_max_num_players {
    my ($self, $new_max) = @_;
    
    my $old_max = @{ $self->{'Players'} };
    if ($new_max > $old_max) {
        foreach my $i ($old_max .. ($new_max-1)) {
            $self->{'Players'}[$i] = Civ4MapCad::Map::Player->new_default($i);
            $self->{'Teams'}{$i} = Civ4MapCad::Map::Team->new_default($i);
        }
        return ($new_max - $old_max);
    }
    else {
        foreach my $i ($new_max .. ($old_max-1)) {
            delete $self->{'Players'}[$i];
            delete $self->{'Teams'}{$i}
        }
        return 0;
    }
}

sub crop {
    my ($self, $left, $bottom, $right, $top) = @_;
    
    my @new;
    
    my $width = $self->{'MapInfo'}->get('grid width');
    my $height = $self->{'MapInfo'}->get('grid height');
    
    foreach my $x (0..$#{$self->{'Tiles'}}) {
        next if $x < $left;
        next if $x > $right;
        $new[$x-$left] = [];
        
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            next if $y < $bottom;
            next if $y > $top;
            $new[$x-$left][$y-$bottom] = $self->{'Tiles'}[$x][$y];
            $new[$x-$left][$y-$bottom]->set('x', $x-$left);
            $new[$x-$left][$y-$bottom]->set('y', $y-$bottom);
        }
    }
    
    $self->{'Tiles'} = \@new;
    $width = $right - $left + 1;
    $height = $top - $bottom + 1;
    
    $self->{'MapInfo'}->set('grid width', $width);
    $self->{'MapInfo'}->set('grid height', $height);
    $self->{'MapInfo'}->set('num plots written', $width*$height);
}

sub fliplr {
    my ($self) = @_;
    
    my @new;
    foreach my $xx (0..$#{$self->{'Tiles'}}) {
        my $x = $#{$self->{'Tiles'}} - $xx;
        $new[$x] = [];
        
        foreach my $y (0..$#{$self->{'Tiles'}[$xx]}) {
            $new[$x][$y] = $self->{'Tiles'}[$xx][$y];
            $new[$x][$y]->set('x', $x);
            $new[$x][$y]->flip_rivers_lr();
        }
    }
    
    $self->{'Tiles'} = \@new;
}

sub fliptb {
    my ($self) = @_;
    
    my @new;
    foreach my $x (0..$#{$self->{'Tiles'}}) {
        $new[$x] = [];
        
        foreach my $yy (0..$#{$self->{'Tiles'}[$x]}) {
            my $y = $#{$self->{'Tiles'}[$x]} - $yy;
            $new[$x][$y] = $self->{'Tiles'}[$x][$yy];
            $new[$x][$y]->set('y', $y);
            $new[$x][$y]->flip_rivers_tb();
        }
    }
    
    $self->{'Tiles'} = \@new;
}

sub set_player_from_civdata {
    my ($self, $owner, $civ_data) = @_;
    $self->{'Players'}[$owner]->set_from_data($civ_data);
    $self->{'Teams'}{$owner}->set('Techs', deepcopy($civ_data->{'_Tech'}));
}

sub set_player_leader {
    my ($self, $owner, $leader_data) = @_;
    
    $self->{'Players'}[$owner]->set('LeaderType', $leader_data->{'LeaderType'});
}

sub set_player_color {
    my ($self, $owner, $color) = @_;
    $self->{'Players'}[$owner]->set('Color', $color);
}

sub set_player_name {
    my ($self, $owner, $name) = @_;
    $self->{'Players'}[$owner]->set('LeaderName', $name);
}

sub fix_coast {
    my ($self) = @_;
    return 1 if $self->{'coast_fixed'};
    
    my @directions = ('1 1', '0 1', '-1 1', '1 0', '-1 0', '1 -1', '0 -1', '-1 -1'); 
    
    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            if ($self->{'Tiles'}[$x][$y]->is_water()) {
                $self->{'Tiles'}[$x][$y]->set('PlotType', 3);
                
                my $make_coast = 0;
                foreach my $direction (@directions) {
                    my ($xd, $yd) = split ' ', $direction;
                    my $tile = $self->get_tile($x+$xd, $y+$yd);
                    my $is_not_water = (defined $tile) ? $tile->is_land() : 0;
                    $make_coast += $is_not_water;
                    last if $make_coast > 0;
                }
                
                if ($make_coast > 0) {
                    $self->{'Tiles'}[$x][$y]->set('TerrainType','TERRAIN_COAST');
                }
                else {
                    $self->{'Tiles'}[$x][$y]->set('TerrainType','TERRAIN_OCEAN');
                }
            }
        }
    }
    
    $self->{'coast_fixed'} = 1;
    
    return 1;
}

sub mark_continents {
    my ($self) = @_;
    
    my $cont_id = 0;
    my %already_checked;
    
    my $is_already_checked = sub {
        my ($x, $y) = @_;
        return 1 if exists $already_checked{"$x/$y"};
        return 0;
    };

    my $mark_as_checked = sub {
        my ($x, $y, $tile) = @_;
        $already_checked{"$x/$y"} = $tile;
    };
    
    my $process = sub {
        my ($mark_as_checked, $tile) = @_;
        $mark_as_checked->($tile->{'x'}, $tile->{'y'}, $tile);
        if ($tile->is_land()) {
            $tile->mark_continent_id($cont_id);
            return 1;
        }
        return 0;
    };
    
    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            my $tile = $self->{'Tiles'}[$x][$y];
            next if exists $already_checked{"$x/$y"};
            next if $tile->is_water();
            
            $self->region_search($tile, $is_already_checked, $mark_as_checked, $process);
            $cont_id ++;
        }
    }
}

sub mark_freshwater {
    my ($self) = @_;
    
    $self->fix_coast();
    $self->mark_rivers();
    
    my %already_checked;
    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            my $tile = $self->{'Tiles'}[$x][$y];
            next if exists $already_checked{"$x/$y"};
            next unless $tile->is_water();
            
            my (%land, %water);
            
            my $is_already_checked = sub {
                my ($x, $y) = @_;
                return 1 if exists($land{"$x/$y"}) or exists($already_checked{"$x/$y"});
                return 0;
            };

            my $mark_as_checked = sub {
                my ($x, $y, $tile) = @_;
                if (! defined($tile)) {
                    $already_checked{"$x/$y"} = $tile;
                }
                elsif ($tile->is_land()) {
                    # land doesn't get marked globally here cause a land tile
                    # can potentially be adjacent to multiple bodies of water
                    $land{"$x/$y"} = $tile;
                }
                else {
                    $already_checked{"$x/$y"} = $tile;
                    $water{"$x/$y"} = $tile;
                }
            };
            
            my $process = sub {
                my ($mark_as_checked, $tile) = @_;
                $mark_as_checked->($tile->get('x'), $tile->get('y'), $tile);
                return 1 if $tile->is_water();
                return 0;
            };
            
            $self->region_search($tile, $is_already_checked, $mark_as_checked, $process);
            
            my @water = keys %water;
            if (@water <= 8) {
                $_->mark_freshwater() foreach (values %water);
                $_->mark_freshwater() foreach (values %land);
            }
            else {
                $_->mark_saltwater_coastal() foreach (values %land);
            }
        }
    }

    # finally, deal with the edgecase of oasis
    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            my $tile = $self->{'Tiles'}[$x][$y];
            next unless $tile->is_land();
            next unless (exists $tile->{'FeatureType'}) and ($tile->{'FeatureType'} eq 'FEATURE_OASIS');
            $tile->mark_freshwater();
            
            my @directions = ('1 1', '0 1', '-1 1', '1 0', '-1 0', '1 -1', '0 -1', '-1 -1');
            foreach my $direction (@directions) {
                my ($xd, $yd) = split ' ', $direction;
                my $subtile = $self->get_tile($x + $xd, $y + $yd);
                next unless defined $subtile;
                $subtile->mark_freshwater();
            }
        }
    }
    
    $self->{'freshwater_marked'} = 1;
    
    return 1;
}

sub mark_rivers {
    my ($self) = @_;
    
    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            my $tile = $self->{'Tiles'}[$x][$y];
            
            if ($tile->is_land()) {
                next if $tile->is_river_adjacent();
            
                # check if a tile is east or south of a river
                
                my $west_tile = $self->get_tile($x-1, $y);
                if (defined($west_tile) and $west_tile->is_WOfRiver()) {
                    $tile->mark_river();
                    next;
                }
                
                my $north_tile = $self->get_tile($x, $y+1);
                if (defined($north_tile) and $north_tile->is_NOfRiver()) {
                    $tile->mark_river();
                    next;
                }
                
                # next, the corners
                
                #  northeast corner
                my $northeast_tile = $self->get_tile($x+1, $y+1);
                if ( (defined($northeast_tile) and $northeast_tile->is_NOfRiver()) and
                     (defined($north_tile)     and $north_tile->is_WOfRiver()) ) {
                    $tile->mark_river();
                    next;
                }
                
                #  southeast corner
                my $east_tile = $self->get_tile($x+1, $y);
                my $south_tile = $self->get_tile($x, $y-1);
                if ( (defined($east_tile) and $east_tile->is_NOfRiver()) and
                     (defined($south_tile) and $south_tile->is_WOfRiver()) ) {
                    $tile->mark_river();
                    next;
                }
                
                #  northwest corner
                my $northwest_tile = $self->get_tile($x-1, $y+1);
                if ( defined($northwest_tile) and $northwest_tile->is_NOfRiver() and$northwest_tile->is_WOfRiver() ) {
                    $tile->mark_river();
                    next;
                }
                
                #  southwest corner
                my $southwest_tile = $self->get_tile($x-1, $y-1);
                if ( (defined($southwest_tile) and $southwest_tile->is_WOfRiver()) and
                     (defined($west_tile) and $west_tile->is_NOfRiver())
                ) {
                    $tile->mark_river();
                    next;
                }
            }
        }
    }
}

sub clear_coasts {
    my ($self) = @_;
    
    my %already_checked;
    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            my $tile = $self->{'Tiles'}[$x][$y];
            $tile->unmark_freshwater();
            
            if ($tile->{'TerrainType'} eq 'TERRAIN_COAST') {
                $tile->{'TerrainType'} = 'TERRAIN_OCEAN';
            }
        }
    }
    
    $self->{'coast_fixed'} = 0;
    $self->{'freshwater_marked'} = 0;
    
    return 1;
}

# is_already_checked - gets x/y, returns 1 or 0 on whether this tile has already been seen
# mark_as_checked - gets x/y/tile, updates is_already_checked
# process - gets a tile, decides how to bin the result. returns 1 if this tile should be added to the queue, 0 otherwise
#
# breadth-first-search for finding a contiguous region, and its surroundings, based on an arbitrary condition
sub region_search {
    my ($self, $start_tile, $is_already_checked, $mark_as_checked, $process) = @_;
    
    my $start_x = $start_tile->{'x'};
    my $start_y = $start_tile->{'y'};
    
    my @queue = ([$start_x, $start_y]);
    $mark_as_checked->($start_x, $start_y, $start_tile);
    
    my @directions = ('1 1', '0 1', '-1 1', '1 0', '-1 0', '1 -1', '0 -1', '-1 -1');
    
    # check all surrounding tiles to the ones we've already found
    while (1) {
        last if @queue == 0;
        my $point = shift @queue;
        my ($x, $y) = @$point;
    
        foreach my $direction (@directions) {
            my ($xd, $yd) = split ' ', $direction;
            my $tx = $x + $xd;
            my $ty = $y + $yd;
            
            next if $is_already_checked->($tx, $ty);
            
            my $tile = $self->get_tile($tx, $ty);
            
            if (! defined($tile)) {
                $mark_as_checked->($tx, $ty, $tile);
                next;
            }
            
            # check again, in case coordinate wrapping from get_tile makes a difference
            $tx = $tile->{'x'};
            $ty = $tile->{'y'};
            next if $is_already_checked->($tx, $ty);
            
            my $to_add = $process->($mark_as_checked, $tile);
            push @queue, [$tx, $ty] if $to_add;
        }
    }
}

sub rotate {
    my ($self, $angle, $it, $autocrop) = @_;
    
    my $width = $self->{'MapInfo'}->get('grid width');
    my $height = $self->{'MapInfo'}->get('grid height');
    my ($grid, $new_width, $new_height, $move_x, $move_y, $result_angle1, $result_angle2) = rotate_grid($self->{'Tiles'}, $width, $height, $angle, $it, $autocrop);
    
    $self->{'MapInfo'}->set('grid width', $new_width);
    $self->{'MapInfo'}->set('grid height', $new_height);
    $self->{'MapInfo'}->set('num plots written', $new_width*$new_height);
    
    $self->{'Tiles'} = [];
    foreach my $x (0..$new_width-1) {
        $self->{'Tiles'}[$x] = [];
        foreach my $y (0..$new_height-1) {
            $self->{'Tiles'}[$x][$y] = $grid->[$x][$y];
            $self->{'Tiles'}[$x][$y] = Civ4MapCad::Map::Tile->new_default($x, $y) unless defined $grid->[$x][$y];
            $self->{'Tiles'}[$x][$y]->set('x', $x);
            $self->{'Tiles'}[$x][$y]->set('y', $y);
        }
    }
    
    return ($new_width, $new_height, $move_x, $move_y, $result_angle1, $result_angle2);
}

sub fix_reveal {
    my ($self) = @_;

    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            $self->{'Tiles'}[$x][$y]->clear_reveals();
        }
    }
    
    my $starts = $self->find_starts();
    foreach my $start (@$starts) {
        my ($start_x, $start_y, $player) = @$start;
        
        foreach my $ddx (0..4) {
            my $dx = $ddx - 2;
            foreach my $ddy (0..4) {
                my $dy = $ddy - 2;
                
                my $tile = $self->get_tile($start_x + $dx, $start_y + $dy);
                next unless defined $tile;
                $tile->add_reveals($player);
            }
        }
    }
    
    return 1;
}
 
sub set_turn0 {
    my ($self) = @_;
    
    if ($self->{'Game'}->get('GameTurn') != 0) {
        $main::state->report_warning("Game turn not 0! Resetting...\n");
        $self->{'Game'}->set('GameTurn', 0)
    }
}
 
 

sub fix_map {
    my ($self) = @_;
    
    $self->fix_techs();
    $self->fix_reveal();
    $self->fix_tiles();
}

sub fix_tiles {
    my ($self) = @_;
    my %already_seen;
    
    # compress the tile warnings
    my $have_warned = 0;
    my $did_short_warn = 0;
    my $warn = sub {
        my ($msg) = @_;
        if ($have_warned == 1) {
            print " * $msg\n";
            $did_short_warn = 1;
        }
        else {
            $main::state->report_warning($msg);
            $have_warned = 1;
        }
    };
    
    if (($self->wrapsX() == 1) and ($self->wrapsY() == 1)) {
        my $width = $self->info('grid width');
        my $height = $self->info('grid height');
        
        if ((($width%4) != 0) or (($height%4) != 0)) {
            $warn->("It is recommended that Toroidal maps have widths and heights divisible by 4 to prevent graphical glitches, but this map has dimensions of ${width}x${height}.");
        }
    }
    
    # first eliminate rivers that are adjacent to coast tiles
    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            my $tile = $self->{'Tiles'}[$x][$y];
        
            if ($tile->is_NOfRiver()) {
                if ($tile->is_water()) {
                    $warn->("Deleting coastal-adjacent river at $x,$y");
                    delete $tile->{'isNOfRiver'};
                    delete $tile->{'RiverNSDirection'}
                }
                else {
                    my $southern_tile = $self->get_tile($x, $y-1);
                    if ($southern_tile->is_water()) {
                        $warn->("Deleting coastal-adjacent river at $x,$y");
                        delete $tile->{'isNOfRiver'};
                        delete $tile->{'RiverNSDirection'}
                    }
                }
            }
            
            if ($tile->is_WOfRiver()) {
                if ($tile->is_water()) {
                    $warn->("Deleting coastal-adjacent river at $x,$y");
                    delete $tile->{'isWOfRiver'};
                    delete $tile->{'RiverWEDirection'}
                }
                else {
                    my $eastern_tile = $self->get_tile($x+1, $y);
                    if ($eastern_tile->is_water()) {
                        $warn->("Deleting coastal-adjacent river at $x,$y");
                        delete $tile->{'isWOfRiver'};
                        delete $tile->{'RiverWEDirection'}
                    }
                }
            }
        }
    }
    
    $self->mark_freshwater();
    
    # now we'll fix features that don't belong
    # this stuff should be pretty self-explanatory
    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            my $tile = $self->{'Tiles'}[$x][$y];
            
            if (exists $tile->{'FeatureType'}) {
                if ($tile->{'FeatureType'} eq 'FEATURE_FLOOD_PLAINS') {
                    if ($tile->is_river_adjacent() == 0) {
                        $warn->("Deleting non-river adjacent floodplain at $x,$y.");
                        delete $tile->{'FeatureType'};
                        delete $tile->{'FeatureVariety'};
                        next;
                    }
                    
                    if (($tile->{'TerrainType'} ne 'TERRAIN_DESERT') and ($tile->{'TerrainType'} ne 'TERRAIN_SNOW')) {
                        $warn->("Deleting floodplain on non- desert/snow tile at $x,$y.");
                        delete $tile->{'FeatureType'};
                        delete $tile->{'FeatureVariety'};
                    }
                }
                elsif ($tile->{'FeatureType'} eq 'FEATURE_OASIS') {
                    if (($tile->{'TerrainType'} ne 'TERRAIN_DESERT') and ($tile->{'TerrainType'} ne 'TERRAIN_SNOW')) {
                        $warn->("Deleting oasis on non- desert/snow tile at $x,$y.");
                        delete $tile->{'FeatureType'};
                        delete $tile->{'FeatureVariety'};
                    }
                }
                elsif ($tile->{'FeatureType'} eq 'FEATURE_JUNGLE') {
                    if (($tile->{'PlotType'} == 0)) {
                        $warn->("Jungle on peak detected (but not deleted) at: $x,$y.");
                    }
                    elsif (($tile->{'PlotType'} == 3)) {
                        $warn->("Deleting watery jungle at: $x,$y.");
                        delete $tile->{'FeatureType'};
                        delete $tile->{'FeatureVariety'};
                    }
                    elsif (($tile->{'TerrainType'} ne 'TERRAIN_GRASS')) {
                        $warn->("Jungle on non-grassland detected (but not deleted) at: $x,$y.");
                    }
                }
                elsif ($tile->{'FeatureType'} eq 'FEATURE_FOREST') {
                    if (($tile->{'PlotType'} == 0)) {
                        $warn->("Forest on peak detected (but not deleted) at: $x,$y.");
                    }
                    elsif (($tile->{'PlotType'} == 3)) {
                        $warn->("Deleting watery forest at: $x,$y.");
                        delete $tile->{'FeatureType'};
                        delete $tile->{'FeatureVariety'};
                    }
                }
            }
        }
    }   
    
    print "\n" if $did_short_warn == 1;
    
    $self->clear_coasts();
}

sub fix_techs {
    my ($self) = @_;
    my $data = $main::state->{'data'}{'civs'};
    
    # first check techs
    # TODO: this won't work for teamer maps!
    foreach my $i (0..$#{ $self->{'Players'} }) {
        my $player = $self->{'Players'}[$i];
        next if $player->{'CivType'} eq 'NONE';
        
        my $team = $self->{'Teams'}{$player->{'Team'}};
        my $actual_techs = $team->{'Techs'};
        my $supposed_techs = $data->{$player->{'CivType'}}{'_Tech'};
        
        my $mismatch = 0;
        my %sts; my %ats;
        @sts{@$supposed_techs} = (1) x @$supposed_techs;
        @ats{@$actual_techs} = (1) x @$actual_techs;
        foreach my $st (@$supposed_techs) {
            if (! exists $ats{$st}) {
                $mismatch = 1;
                $main::state->report_warning("Player $i ($player->{'LeaderName'} of $player->{'CivType'}) is supposed to have $st but is missing it!");
            }
        }
        foreach my $at (@$actual_techs) {
            if (! exists $sts{$at}) {
                $mismatch = 1;
                $main::state->report_warning("Player $i ($player->{'LeaderName'} of $player->{'CivType'}) has $at but isn't supposed to!");
            }
        }
        
        if ($mismatch == 1) {
            $main::state->report_warning("Setting techs to the default techs of $player->{'CivType'}.");
            $self->{'Teams'}{$player->{'Team'}}{'Techs'} = [];
            foreach my $t (@{ $data->{$player->{'CivType'}}{'_Tech'} }) {
                $team->add_tech($t);
            }
        }
    }
}
 
1;