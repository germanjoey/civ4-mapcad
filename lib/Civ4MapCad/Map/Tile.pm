package Civ4MapCad::Map::Tile;

use strict;
use warnings;

our @fields = qw(x y isNOfRiver isWOfRiver RouteType RiverNSDirection RiverWEDirection BonusType FeatureType FeatureVariety TerrainType PlotType ImprovementType TeamReveal);
our %field_names;
@field_names{@fields} = (1) x @fields;

our $DEBUG = 0;

use Civ4MapCad::Map::Unit;
use Civ4MapCad::Util qw(write_block_data);
use Civ4MapCad::ColorConversion qw(mix_colors_by_alpha);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $obj = bless {}, $class;
    
    $obj->{'freshwater'} = 0;
    $obj->{'coastal'} = 0;
    $obj->{'river_adjacent'} = 0;
    $obj->{'continent_id'} = -1;
    $obj->{'Revealed'} = {};
    $obj->{'Units'} = [];
    
    return $obj;
}

sub new_default {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $obj = bless {}, $class;
    
    $obj->{'freshwater'} = 0;
    $obj->{'coastal'} = 0;
    $obj->{'river_adjacent'} = 0;
    $obj->{'continent_id'} = -1;
    $obj->{'Revealed'} = {};
    $obj->{'Units'} = [];
    
    my ($x, $y) = @_;
    $obj->default($x, $y);
    return $obj;
}
    
sub default {
    my ($self, $x, $y) = @_;
    
    $self->set('x', $x);
    $self->set('y', $y);
    $self->set('TerrainType', 'TERRAIN_OCEAN');
    $self->set('PlotType', 3);
    $self->{'freshwater'} = 0;
    $self->{'coastal'} = 0;
    $self->{'river_adjacent'} = 0;
    $self->{'continent_id'} = -1;
}

sub clear {
    my ($self) = @_;
    
    delete $self->{$_} foreach (@fields);
    $self->{'Revealed'} = {};
    $self->{'Units'} = [];
    $self->{'freshwater'} = 0;
    $self->{'coastal'} = 0;
    $self->{'river_adjacent'} = 0;
    $self->{'continent_id'} = -1;
}

sub clear_reveals {
    my ($self) = @_;
    $self->{'Revealed'} = {};
}

sub add_reveals {
    my ($self, @vals) = @_;
    
    foreach my $val (@vals) {
        next unless $val =~ /\d/;
        $val =~ s/\s//g;
        $self->{'Revealed'}{$val} = 1;
    }
}

sub get_revealed {
    my ($self) = @_;
    return sort {$a <=> $b} keys %{ $self->{'Revealed'} };
}

sub add_unit {
    my ($self, $unit) = @_;
    push @{ $self->{'Units'} }, $unit;
}

sub get_units {
    my ($self) = @_;
    return @{ $self->{'Units'} };
}

sub get {
    my ($self, $key) = @_;
    return $self->{$key};
}

sub set {
    my ($self, $key, $value) = @_;
    $self->{$key} = $value;
}

sub parse {
    my ($self, $fh, $strip_nonsettlers) = @_;
    
    # begin unit is already found
    while (1) {
        my $line = <$fh>;
        next if $line !~ /\w/;
        next if $line =~ /^\s*#/;
        return if $line =~ /EndPlot/i;
        chomp $line;
        $line =~ s/^\s*//;
        $line =~ s/\s*$//;
        
        if ($line =~ /^\s*BeginUnit/i) {
            my $unit = Civ4MapCad::Map::Unit->new();
            $unit->parse($fh);
            $self->add_unit($unit);
            next;
        }
        
        if ($line =~ /^\s*BeginCity/i) {
            $main::state->report_warning("Cities are not currently supported by this tool. Converting to settler...", 1);
            
            my $player = -1;
            
            while (1) {
                my $line = <$fh>;
                if ($line =~ /CityOwner/) {
                    ($player) = $line =~ /CityOwner\s*=\s*(\d+)/;
                }
                last if $line =~ /EndCity/;
            }
            
            if ($player != -1) {
                my $unit = Civ4MapCad::Map::Unit->new();
                $unit->set('UnitType', 'UNIT_SETTLER');
                $unit->set('UnitOwner', $player);
                $unit->set('Damage', '0');
                $unit->set('Level', '1');
                $unit->set('Experience', '0');
                $unit->set('FacingDirection', '4');
                $unit->set('UnitAIType', 'UNITAI_SETTLE');
                $self->add_unit($unit);
            }
            next;
        }
        
        my @pieces = split ',', $line;
        if ($pieces[0] =~ /TeamReveal/i) {
            my $first = shift @pieces;
            my ($name, $value1) = split '=', $first;
            
            $self->add_reveals($value1, @pieces);
        }
        
        elsif ($pieces[0] =~ /isNOfRiver/i) {
            $self->set('isNOfRiver', 1);
        }
        
        elsif ($pieces[0] =~ /isWOfRiver/i) {
            $self->set('isWOfRiver', 1);
        }
        
        else {
            foreach my $piece (@pieces) {
                $piece =~ s/,$//;
                $piece =~ s/^\s*//;
                $piece =~ s/\s*$//;
                my ($name, $value) = split '=', $piece;
            
                $self->set($name, $value);
            }
        }
    }
    
    if ($strip_nonsettlers) {
        $self->strip_nonsettlers();
    }
    
    $self->{'freshwater'} = 0;
}

sub flip_rivers_tb {
    my ($self) = @_;
    
    if (exists $self->{'RiverNSDirection'}) {
        $self->{'RiverNSDirection'} = ($self->{'RiverNSDirection'} == 0) ? 2 : 0;
    }
}

sub flip_rivers_lr {
    my ($self) = @_;
    
    if (exists $self->{'RiverWEDirection'}) {
        $self->{'RiverWEDirection'} = ($self->{'RiverWEDirection'} == 1) ? 3 : 1;
    }
}

sub transpose_rivers {
    my ($self) = @_;
    
    if ((exists $self->{'isNOfRiver'}) and (exists $self->{'isWOfRiver'})) {
        my $ns = $self->{'RiverNSDirection'};
        $self->{'RiverNSDirection'} = ($self->{'RiverWEDirection'} == 1) ? 0 : 2;
        $self->{'RiverWEDirection'} = ($ns == 0) ? 1 : 3;
    }
    elsif (exists $self->{'isNOfRiver'}) {
        $self->{'isWOfRiver'} = 1;
        $self->{'RiverNSDirection'} = ($self->{'RiverWEDirection'} == 1) ? 0 : 2;
        delete $self->{'isNOfRiver'};
        delete $self->{'RiverWEDirection'};
    }
    elsif (exists $self->{'isWOfRiver'}) {
        $self->{'isNOfRiver'} = 1;
        $self->{'RiverWEDirection'} = ($self->{'RiverNSDirection'} == 0) ? 1 : 3;
        delete $self->{'isWOfRiver'};
        delete $self->{'RiverNSDirection'};
    }
}

sub write {
    my ($self, $fh) = @_;
    print $fh "BeginPlot\n";
    
    # can't use write_block_data cause this is a special case where we can't have a space between the x and the y =/
    my $x = $self->get('x'); my $y = $self->get('y');
    print $fh "\tx=$x,y=$y\n";
    
    write_block_data($self, $fh, 1, 'RiverNSDirection');
    print $fh "\tisNOfRiver\n" if $self->get('isNOfRiver');
    
    write_block_data($self, $fh, 1, 'RiverWEDirection');
    print $fh "\tisWOfRiver\n" if $self->get('isWOfRiver');
    
    write_block_data($self, $fh, 1, 'RouteType');
    write_block_data($self, $fh, 1, 'BonusType');
    write_block_data($self, $fh, 1, 'ImprovementType');
    write_block_data($self, $fh, 1, 'FeatureType', 'FeatureVariety');
    write_block_data($self, $fh, 1, 'TerrainType');
    write_block_data($self, $fh, 1, 'PlotType');
    
    my @units = $self->get_units();
    foreach my $unit (@units) {
        $unit->write($fh);
    }
    
    my @revealed = $self->get_revealed();
    if (@revealed > 0) {
        $self->set('TeamReveal', join(',', @revealed) . ',');
        write_block_data($self, $fh, 1, 'TeamReveal');
    }
    
    if ($DEBUG == 1) {
        write_block_data($self, $fh, 1, 'freshwater');
        write_block_data($self, $fh, 1, 'coastal');
        write_block_data($self, $fh, 1, 'river_adjacent');
        write_block_data($self, $fh, 1, 'continent_id');
        write_block_data($self, $fh, 1, 'value');
        write_block_data($self, $fh, 1, 'up_value');
        write_block_data($self, $fh, 1, 'bfc_value');
        write_block_data($self, $fh, 1, 'avg_value');
        write_block_data($self, $fh, 1, 'fr_value');
        write_block_data($self, $fh, 1, 'food');
        write_block_data($self, $fh, 1, 'frf');
        write_block_data($self, $fh, 1, 'trees');
        write_block_data($self, $fh, 1, 'river');
        write_block_data($self, $fh, 1, 'bad');
        
        
        if (exists $self->{'yld'}) {
            print $fh "\t" x 1;
            print $fh  'yld', "=";
            print $fh  " $self->{'yld'}[0] / $self->{'yld'}[1] / $self->{'yld'}[2]";
            print $fh  "\n";
        }
        
        if (exists $self->{'up_yld'}) {
            print $fh "\t" x 1;
            print $fh  'up_yld', "=";
            print $fh  " $self->{'up_yld'}[0] / $self->{'up_yld'}[1] / $self->{'up_yld'}[2]";
            print $fh  "\n";
        }
    }
    
    print $fh "EndPlot\n";
}

sub fill {
    my ($self) = @_;
    my ($x, $y) = ($self->get('x'), $self->get('y'));
    
    $self->clear;
    
    $self->set('x', $x);
    $self->set('y', $y);
    $self->set('TerrainType', 'TERRAIN_GRASS');
    $self->set('PlotType', 1);
}

sub is_land {
    my ($self) = @_;
    return (($self->{'TerrainType'} eq 'TERRAIN_OCEAN') or ($self->{'TerrainType'} eq 'TERRAIN_COAST')) ? 0 : 1;
}

sub is_coast {
    my ($self) = @_;
    
    return ($self->{'TerrainType'} eq 'TERRAIN_COAST') ? 1 : 0;
}
sub is_saltwater_coastal {
    my ($self) = @_;
    
    return $self->{'coastal'};
}

sub has_bonus {
    my ($self) = @_;
    
    return ((exists $self->{'BonusType'}) and defined($self->{'BonusType'}) and ($self->{'BonusType'} =~ /\w/)) ? 1 : 0;
}

sub has_feature {
    my ($self) = @_;
    
    return (exists $self->{'FeatureType'} and defined($self->{'BonusType'}) and ($self->{'BonusType'} =~ /\w/)) ? 1 : 0;
}

sub is_water {
    my ($self) = @_;
    
    return (($self->{'TerrainType'} eq 'TERRAIN_OCEAN') or ($self->{'TerrainType'} eq 'TERRAIN_COAST')) ? 1 : 0;
}

sub is_coastal {
    my ($self) = @_;
    return ($self->is_land() and ($self->{'coastal'} == 1)) ? 1 : 0;
}

sub is_blank {
    my ($self) = @_;  
    return (($self->{'freshwater'} == 0) and ($self->is_water()) and (!$self->has_bonus()) and (! $self->has_feature())) ? 1 : 0;
}

sub update_tile {
    my ($self, $terrain, $allowed) = @_;
    
    foreach my $key (keys %$terrain) {
        return -1 unless exists $field_names{$key};
        next if exists($allowed->{$key}) and ($allowed->{$key} == 0);
        
        $self->{$key} = $terrain->{$key};
    }
    
    foreach my $key (keys %$allowed) {
        next if exists $terrain->{$key};
        delete $self->{$key} if exists $self->{$key};
    }
    
    return 1;
}

sub set_tile {
    my ($self, $terrain) = @_;
    
    my $x = $self->get('x');
    my $y = $self->get('y');
    $self->clear();
    
    $self->update_tile($terrain);
    $self->set('x', $x);
    $self->set('y', $y);
    
    return 1;
}

sub to_cell {
    my ($self, $add_alloc, $alloc) = @_;
    
    my $river = '';
    $river .= " iNR" if $self->get('isNOfRiver');
    $river .= " iWR" if $self->get('isWOfRiver'); 
    my $tt = lc($self->get('TerrainType'));
    
    $tt = 'peak' if $self->get('PlotType') eq '0';
    
    my $terrain = $tt;
    $terrain =~ s/terrain_//;
    
    my $icon = qq[<img src="i/none.png"/>];
    
    my $bonus = $self->get('BonusType');
    if ($bonus) {
        $bonus = lc($bonus);
        $bonus =~ s/bonus_//;
        
        my $class = '';
        if ($bonus =~ /corn|rice|wheat|pig|deer|sheep|cow|fish|clam|crab|corn|banana/i) {
            $class = 'fd';
        }
        elsif ($bonus =~ /copper|horse|iron|stone|marble/i) {
            $class = 'es';
        }
        elsif ($bonus =~ /oil|uranium|alum|coal/i) {
            $class = 'ms';
        }
        elsif ($bonus =~ /fur|ivory|whale|gold|silver|gems/i) {
            if ((exists $self->{'FeatureType'}) and ($self->{'FeatureType'} =~ /jungle/i)) {
                if ($bonus =~ /fur|ivory/) {
                    $class = 'al';
                }
                else {
                    $class = 'cl';
                }
            }
            else {
                $class = 'al';
            }
        }
        elsif ($bonus =~ /dye|silk|sugar|wine|incense|spice/i) {
            $class = 'cl';
        }
        
        $class = qq[class="$class"] if $class ne '';
        $icon = qq[<img $class src="i/$bonus.png" />];
    }
    
    my $variety = '';
    my $variety_tag = '';
    my $feature = $self->get('FeatureType');
    
    if ($feature) {
        if ($feature =~ /oasis/i) {
            $icon = qq[<img src="i/oasis.png" />];
            $variety_tag = ' oasis';
        }
        
        if ($feature =~ /forest/i) {
            $variety_tag = ($self->get('PlotType') eq '1') ? ' foresthill' : ' forest';
            $variety = ($self->get('PlotType') eq '1') ? ' fthl' : ' ft';
        }
        elsif ($feature =~ /jungle/i) {
            $variety_tag = ($self->get('PlotType') eq '1') ? ' junglehill' : ' jungle';
            $variety = ($self->get('PlotType') eq '1') ? ' jlhl' : ' jl';
        }
    }
    elsif ($self->get('PlotType') eq '1') {
        $variety_tag = ' hill';
        $variety = ' hl';
    }
    
    $bonus = (defined $bonus) ? "$bonus, " : '';
    my $title = " $bonus $terrain $variety_tag";
    
    if ($self->has_settler()) {
        $icon = qq[<img src="i/razz.gif" />];
        
        my @starts;
        foreach my $start ($self->get_starts()) {
            my ($start_x, $start_y, $player_number) = @$start;
            
            my $player_name = "player $player_number";
            if (exists $main::state->{'current_debug'}) {
                my ($player, $team) = $main::state->{'current_debug'}->get_player_data($player_number);
                
                my $leader_type = 'none';
                if (exists $player->{'LeaderType'}) {
                    $leader_type = "$player->{'LeaderType'}";
                    $leader_type =~ s/^LEADER_//;
                    $leader_type =~ s/_/ /g;
                    $leader_type = join ' ', map { ucfirst(lc($_)) } (split ' ', $leader_type);
                }
                
                my $civ_type = 'none';
                if (exists $player->{'CivType'}) {
                    $civ_type = "$player->{'CivType'}";
                    $civ_type =~ s/^CIVILIZATION_//;
                    $civ_type =~ s/_/ /g;
                    $civ_type = join ' ', map { ucfirst(lc($_)) } (split ' ', $civ_type);
                }
            
                if (exists $player->{'LeaderName'}) {
                    $player_name = "$player->{'LeaderName'} ($player_number) ($leader_type/$civ_type)";
                }
                else {
                    $player_name = "$player_name ($leader_type/$civ_type)";
                }
                
                push @starts, $player_name;
            }
        }
        
        $title = " start for " . join (" and ", @starts) . ", " . $title;
    }
    
    $title =  $self->get('x') . ',' . $self->get('y') . $title;
    $title =~ s/\s+/ /g;
    $title =~ s/\s+$//;
    
    my $title_alloc = '';
    my $cell_alloc = '';
    if ($add_alloc) {
        ($title_alloc, $cell_alloc) = $self->alloc_cell($alloc);
    }
    
    $tt =~ s/terrain_//;
    my $full_title = qq[ title="$title$title_alloc"];
    $tt = substr($tt,0,2);
    my $cell = qq[<a$full_title>$icon</a>];
    return qq[<td><div class="w"><div class="$tt$variety$river">$cell</div>$cell_alloc</div></td>];
}

sub alloc_cell {
    my ($self, $alloc) = @_;
    return ('','') unless defined $alloc;
    
    my $title_alloc = '';
    my $cell_alloc = '';
    
    my @colors;
    foreach my $civ (%$alloc) {
        next unless exists $alloc->{$civ};
        next if $alloc->{$civ} < 0.05;
        push @colors, [$civ, $alloc->{$civ}];
    }
    
    if (@colors == 0) {
        return ('', '');
    }
    
    my @mixed_colors = mix_colors_by_alpha(@colors);
    
    foreach my $i (0..$#mixed_colors) {
        my ($civ, $ownership, $alpha) = @{ $mixed_colors[$i] };
        my $z = @mixed_colors - $i;
        
        my $o = int(100*$alpha + 0.5);
        $cell_alloc .= qq[<div class="c$civ o$o z$z"></div>];
    }
    
    @mixed_colors = sort { $a->[0] <=> $b->[0] } @mixed_colors;
    foreach my $i (0..$#mixed_colors) {
        my ($civ, $ownership, $alpha) = @{ $mixed_colors[$i] };
        my $op = int(100*$ownership + 0.5);
        $title_alloc .= "$civ: $op\%, ";
    }
    
    $title_alloc =~ s/, $//;
    $title_alloc = " ($title_alloc)" if $title_alloc =~ /\d/;
    
    return ($title_alloc, $cell_alloc);
}

sub strip_hidden_strategic {
    my ($self) = @_;
    
    return unless exists $self->{'BonusType'};
    my $bonus = $self->get('BonusType');
    if ($bonus =~ /IRON|URANIUM|ALUMINUM|COPPER|HORSE|OIL|COAL/) {
        delete $self->{'BonusType'};
    }
}

sub strip_all_units {
    my ($self) = @_;
    $self->{'Units'} = [];
}

sub strip_nonsettlers {
    my ($self) = @_;
    my @stripped;
    foreach my $unit (@{ $self->{'Units'} }) {
        if ($unit->is_settler()) {
            push @stripped, $unit;
        }
    }
    
    $self->{'Units'} = \@stripped;
}

sub has_settler {
    my ($self) = @_;
    
    foreach my $unit (@{ $self->{'Units'} }) {
        if ($unit->is_settler()) {
            return 1;
        }
    }
    
    return 0;
}

sub get_starts {
    my ($self) = @_;
    
    my @starts;
    foreach my $unit (@{ $self->{'Units'} }) {
        if ($unit->is_settler()) {
            push @starts, [$self->get('x'), $self->get('y'), $unit->get('UnitOwner')];
        }
    }
    
    return @starts;
}

sub reassign_starts {
    my ($self, $old, $new) = @_;
    
    my @starts;
    foreach my $unit (@{ $self->{'Units'} }) {
        if (($unit->is_settler()) and ($unit->get('UnitOwner') eq $old)) {
            $unit->set('UnitOwner', $new)
        }
    }
}

sub reassign_units {
    my ($self, $old, $new) = @_;
    
    my @starts;
    foreach my $unit (@{ $self->{'Units'} }) {
        if ($unit->get('UnitOwner') eq $old) {
            $unit->set('UnitOwner', $new)
        }
    }
}

sub add_scout_if_settler {
    my ($self) = @_;
    
    my @added;
    foreach my $unit (@{ $self->{'Units'} }) {
        if ($unit->is_settler()) {
            push @added, $unit;
            my $scout = Civ4MapCad::Map::Unit->new();
            my $owner = $unit->get('UnitOwner');
            
            $scout->set('UnitType','UNIT_SCOUT'); $scout->set('UnitOwner',$owner);
            $scout->set('Damage','0');
            $scout->set('Level','1'); $scout->set('Experience','0');
            $scout->set('FacingDirection','2');
            $scout->set('UnitAIType','UNITAI_EXPLORE');
            
            #push @added, $scout;
            push @{$self->{'Units'}}, $scout;
        }
        
        #push @added, $unit;
    }
    
    #$self->{'Units'} = \@added;
}

sub reassign_reveals {
    my ($self, $old, $new) = @_;
    
    if (exists $self->{'Revealed'}{$old}) {
        delete $self->{'Revealed'}{$old};
        $self->{'Revealed'}{$new} = 1;
    }
}

# either we have a river explicitly on us, or freshwater was marked by Map because of some other tile
sub is_fresh {
    my ($self) = @_;
    if (($self->{'freshwater'} == 1) or $self->is_river_adjacent()) {
        return 1;
    }
    return 0;
}

sub mark_continent_id {
    my ($self, $id) = @_;
    $self->{'continent_id'} = $id;
}

sub mark_river {
    my ($self) = @_;
    $self->{'river_adjacent'} = 1;
}

sub mark_freshwater {
    my ($self) = @_;
    $self->{'freshwater'} = 1;
}

# saltwater coast, e.g. can make a lighthouse/ships
sub mark_saltwater_coastal {
    my ($self) = @_;
    $self->{'coastal'} = 1;
}

sub unmark_freshwater {
    my ($self) = @_;
    $self->{'freshwater'} = 0;
    $self->{'river_adjacent'} = 0;
    $self->{'coastal'} = 0;
}

sub is_river_adjacent {
    my ($self) = @_;
    if ($self->is_land() and (($self->{'river_adjacent'} == 1) or exists($self->{'isNOfRiver'}) or exists($self->{'isWOfRiver'}))) {
        return 1;
    }
    return 0;
}

sub is_NOfRiver {
    my ($self) = @_;
    return (exists $self->{'isNOfRiver'}) ? 1 : 0;
}

sub is_WOfRiver {
    my ($self) = @_;
    return (exists $self->{'isWOfRiver'}) ? 1 : 0;
}

sub compare {
    my ($self, $terrain, $exact) = @_;
    
    if ($exact) {
        foreach my $key (@fields) {
            next if ($key eq 'isNOfRiver') or ($key eq 'isWOfRiver');
            next unless exists $self->{$key};
            next if ($key eq 'TeamReveal') or ($key eq 'x') or ($key eq 'y');
            next if $key =~ /^River/;
            return 0 unless exists $terrain->{$key};
            return 0 unless $self->{$key} eq $terrain->{$key};
        }
        foreach my $key (keys %$terrain) {
            return 0 unless exists $self->{$key};
            return 0 unless $self->{$key} eq $terrain->{$key};
        }
        
        return 1;
    }
    else {
        foreach my $key (keys %$terrain) {
            return 0 unless exists $self->{$key};
            return 0 unless $self->{$key} eq $terrain->{$key};
        }
        return 1;
    }
    
    return 1;
}

1;