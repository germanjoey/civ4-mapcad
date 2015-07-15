package Civ4MapCad::Map;

use strict;
use warnings;

use List::Util qw(min max);
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

# TODO: set up a unified interface?
sub info {
    my ($self, $field) = @_;
    return $self->{'MapInfo'}->get($field);
}

sub default {
    my ($self, $width, $height) = @_;
    
    $self->{'Game'} = Civ4MapCad::Map::Game->new_default();
    $self->{'MapInfo'} = Civ4MapCad::Map::MapInfo->new_default($width, $height);
    
    foreach my $i (0..$main::config{'max_players'}-1) {
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
}

sub clear {
    my ($self) = @_;
    
    $self->{'Signs'} = [];
    $self->{'Game'}->clear();
    $self->{'MapInfo'}->clear();
    
    foreach my $team ($self->get_teams()) {
        $team->clear();
        delete $self->{'Teams'}{$team};
    }
    
    foreach my $player ($self->get_players()) {
        $player->clear();
    }
    $self->{'Players'} = [];
    
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
}

sub expand_dim {
    my ($self, $new_width, $new_height) = @_;
    
    my $current_width = $self->info('grid width');
    my $current_height = $self->info('grid width');
    
    my $width = max($new_width, $current_width);
    my $height = max($new_height, $current_height);
    
    $self->{'MapInfo'}->set('grid width', $width);
    $self->{'MapInfo'}->set('grid height', $height);
    $self->{'MapInfo'}->set('num plots written', $width*$height);
    # $self->{'MapInfo'}->set('num signs written', $num_signs);
    
    foreach my $x (0..$width-1) {
        $self->{'Tiles'}[$x] = [] unless defined $self->{'Tiles'}[$x];
        foreach my $y (0..$height-1) {
            $self->{'Tiles'}[$x][$y] = Civ4MapCad::Map::Tile->new_default() unless defined $self->{'Tiles'}[$x][$y];
        }
    }
}

sub wrapsX {
    my ($self) = @_;
    return defined($self->info('wrap X')) and ($self->info('wrap X') eq '1');
}

sub wrapsY {
    my ($self) = @_;
    return defined($self->info('wrap Y')) and ($self->info('wrap Y') eq '1');
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
    if ($max_players != $main::config{'max_players'}) {
        $main::config{'state'}->report_warning("Converting map '$filename' from $max_players to $main::config{'max_players'} players. Set 'mod' in def/config.cfg or use the 'set_mod' command to prevent automatic conversion on import.", 1);
        $self->set_max_num_players($main::config{'max_players'});
    }
    
    close $fh;
    
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

sub get_tile {
    my ($self, $x, $y) = @_;
    
    my $ux = $x;
    my $uy = $y;
    
    if ($x > $#{ $self->{'Tiles'} }) {
        return unless $self->wrapsX();
        my $oldX = $ux;
        $ux = $ux - $self->info('grid width');
    }
    elsif ($x < 0) {
        return unless $self->wrapsX();
        my $oldX = $ux;
        $ux = $ux + $self->info('grid width');
    }
    
    if ($y > $#{ $self->{'Tiles'}[$ux] }) {
        return unless $self->wrapsY();
        my $oldY = $uy;
        $uy = $uy - $self->info('grid height');
    }
    elsif ($y < 0) {
        return unless $self->wrapsY();
        my $oldY = $uy;
        $uy = $uy + $self->info('grid height');
    }
    
    return $self->{'Tiles'}[$ux][$uy];
}

sub fix_coast {
    my ($self) = @_;

    foreach my $x (0..$#{$self->{'Tiles'}}) {
        foreach my $y (0..$#{$self->{'Tiles'}[$x]}) {
            warn "$x $y" unless defined $self->{'Tiles'}[$x][$y];
            if ($self->{'Tiles'}[$x][$y]->is_water()) {
                $self->{'Tiles'}[$x][$y]->set('PlotType', 3);

                my $xp1_yp1 = (defined $self->get_tile($x+1, $y+1)) ? ($self->get_tile($x+1, $y+1)->is_land()) : 0;
                my $x00_yp1 = (defined $self->get_tile($x+0, $y+1)) ? ($self->get_tile($x+0, $y+1)->is_land()) : 0;
                my $xm1_yp1 = (defined $self->get_tile($x-1, $y+1)) ? ($self->get_tile($x-1, $y+1)->is_land()) : 0;
                my $xp1_y00 = (defined $self->get_tile($x+1, $y+0)) ? ($self->get_tile($x+1, $y+0)->is_land()) : 0;
                
                my $xm1_y00 = (defined $self->get_tile($x-1, $y+0)) ? ($self->get_tile($x-1, $y+0)->is_land()) : 0;
                my $xp1_ym1 = (defined $self->get_tile($x+1, $y-1)) ? ($self->get_tile($x+1, $y-1)->is_land()) : 0;
                my $x00_ym1 = (defined $self->get_tile($x+0, $y-1)) ? ($self->get_tile($x+0, $y-1)->is_land()) : 0;
                my $xm1_ym1 = (defined $self->get_tile($x-1, $y-1)) ? ($self->get_tile($x-1, $y-1)->is_land()) : 0;
                
                my $make_coast = $xp1_yp1 + $x00_yp1 + $xm1_yp1 + $xp1_y00 + $xm1_y00 + $xp1_ym1 + $x00_ym1 + $xm1_ym1;
                
                if ($make_coast > 0) {
                    $self->{'Tiles'}[$x][$y]->set('TerrainType','TERRAIN_COAST');
                }
                else {
                    $self->{'Tiles'}[$x][$y]->set('TerrainType','TERRAIN_OCEAN');
                }
            }
        }
    }
    
    return 1;
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
    
    foreach my $player (@{ $self->{'Players'} }) {
        $player->set('Handicap', 'HANDICAP_' . uc($level));
    }
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
    }
    else {
        foreach my $i ($new_max .. ($old_max-1)) {
            delete $self->{'Players'}[$i];
            delete $self->{'Teams'}{$i}
        }
    }
}

sub crop {
    my ($self, $left, $bottom, $right, $top) = @_;
    
    my @new;
    
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
    my $width = $right - $left + 1;
    my $height = $top - $bottom + 1;
    
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
        }
    }
    
    $self->{'Tiles'} = \@new;
}
    
1;