package Civ4MapCad::Map::Tile;

use strict;
use warnings;

our @fields = qw(x y isNOfRiver isWOfRiver RouteType RiverNSDirection RiverWEDirection BonusType FeatureType FeatureVariety TerrainType PlotType ImprovementType TeamReveal);
our %field_names;
@field_names{@fields} = (1) x @fields;

our $DEBUG = 0;

use Civ4MapCad::Map::Unit;
use Civ4MapCad::Util qw(write_block_data);

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
            $main::config{'state'}->report_warning("Cities are not currently supported by this tool. Skipping...", 1);
            while (1) {
                my $line = <$fh>;
                last if $line =~ /EndCity/;
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
    my ($self) = @_;
    
    my $river = '';
    $river .= " isNOfRiver" if $self->get('isNOfRiver');
    $river .= " isWOfRiver" if $self->get('isWOfRiver'); 
    my $tt = lc($self->get('TerrainType'));
    
    $tt = 'terrain_peak' if $self->get('PlotType') eq '0';
    
    my $terrain = $tt;
    $terrain =~ s/terrain_//;
    
    my $icon = qq[<img src="debug/icons/none.png" />];
    
    my $bonus = $self->get('BonusType');
    if ($bonus) {
        $bonus = lc($bonus);
        $bonus =~ s/bonus_//;
        $icon = qq[<img src="debug/icons/$bonus.png" />];
    }
    
    my $variety = '';
    my $feature = $self->get('FeatureType');
    if ($feature) {
        if ($feature =~ /oasis/i) {
            $icon = qq[<img src="debug/icons/oasis.png" />];
            $variety = ' oasis';
        }
        
        if ($feature =~ /forest/i) {
            $variety = ($self->get('PlotType') eq '1') ? ' foresthill' : ' forest';
        }
        elsif ($feature =~ /jungle/i) {
            $variety = ($self->get('PlotType') eq '1') ? ' junglehill' : ' jungle';
        }
    }
    elsif ($self->get('PlotType') eq '1') {
        $variety = ' hill';
    }
    
    $bonus = (defined $bonus) ? "$bonus, " : '';
    my $title = " $bonus $terrain $variety";
    
    if ($self->has_settler()) {
        $icon = qq[<img src="debug/icons/razz.gif" />];
        my @starts = map { $_->[2] } ($self->get_starts());
        $title = " start for player " . join ("/", @starts) . ", " . $title;
    }
    
    $title =  $self->get('x') . ',' . $self->get('y') . $title;
    $title =~ s/\s+/ /g;
    
    my $cell = qq[<a title="$title">$icon</a>];
    return qq[<td class="tooltip"><div class="$tt$variety$river">$cell</div></td>];
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
            
            push @added, $scout;
        }
        
        push @added, $unit;
    }
    
    $self->{'Units'} = \@added;
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