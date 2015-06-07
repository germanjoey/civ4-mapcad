package Civ4MapCad::Map;

use strict;
use warnings;

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
    
    $self->{'Game'} = Civ4MapCad::Map::Game->new_default;
    $self->{'MapInfo'} = Civ4MapCad::Map::MapInfo->new_default($width, $height);
    
    # TODO: num teams is dependent on mod
    foreach my $i (0..17) {
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
    my ($self, $width, $height) = @_;
    
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

sub overwrite_tiles {
    my ($self, $map, $offsetX, $offsetY) = @_;
    
    my $width = $map->info('grid width');
    my $height = $map->info('grid height');
    
    for my $x (0..$width-1) {
        for my $y (0..$height-1) {
            if (! $map->{'Tiles'}[$x][$y]->is_blank()) {
                $self->{'Tiles'}[$x + $offsetX][$y + $offsetY] = deepcopy($map->{'Tiles'}[$x][$y]);
                $self->{'Tiles'}[$x + $offsetX][$y + $offsetY]->set('x', $x + $offsetX);
                $self->{'Tiles'}[$x + $offsetX][$y + $offsetY]->set('y', $y + $offsetX);
            }
        }
    }
}

sub add_player {
    my ($self, $fh) = @_;
    
    my $player = Civ4MapCad::Map::Player->new;
    $player->parse($fh);
    push @{ $self->{'Players'} }, $player;
}

sub get_players {
    my ($self, $fh) = @_;
    return @{$self->{'Players'}};
}

sub add_team {
    my ($self, $fh) = @_;
    
    my $team = Civ4MapCad::Map::Team->new;
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
    
    my $sign = Civ4MapCad::Map::Sign->new;
    $sign->parse($fh);
    push @{$self->{'Signs'}}, $sign;
}

sub add_tile {
    my ($self, $fh) = @_;
    
    my $tile = Civ4MapCad::Map::Tile->new;
    $tile->parse($fh);
    
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
    my ($self, $filename) = @_;
    
    open (my $fh, $filename) or die $!;
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
            $self->add_player($fh);
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
            die "Unidentified block found when importing: '$line'";
        }
    }
    
    close $fh;
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