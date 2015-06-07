package Civ4MapCad::Map::Team;

use strict;
use warnings;

our @fields = qw(TeamID RevealMap);
our %field_names;
@field_names{@fields} = (1) x @fields;

use Civ4MapCad::Util qw(write_block_data);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    
    my $obj = bless {}, $class;
    $obj->{'Contacts'} = [];
    $obj->{'Techs'} = [];
    $obj->{'AtWars'} = [];
    $obj->{'PermanentWarPeaces'} = [];
    $obj->{'OpenBordersWithTeams'} = [];
    $obj->{'DefensivePactWithTeams'} = [];
    $obj->{'ProjectTypes'} = [];
    
    return $obj;
}

sub new_default {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $obj = bless {}, $class;
    
    my $teamID = shift;
    $obj->default($teamID);
    return $obj;
}

sub default {
    my ($self, $teamID) = @_;
    $self->clear();
    $self->set('TeamID', $teamID);
    $self->set('ContactWithTeam', $teamID);
    $self->set('RevealMap', 0);
}

sub clear {
    my ($self) = @_;
    
    delete $self->{$_} foreach (@fields);

    $self->{'Contacts'} = [];
    $self->{'Techs'} = [];
    $self->{'AtWars'} = [];
    $self->{'PermanentWarPeaces'} = [];
    $self->{'OpenBordersWithTeams'} = [];
    $self->{'DefensivePactWithTeams'} = [];
    $self->{'ProjectTypes'} = [];
}

sub get {
    my ($self, $key) = @_;
    return $self->{$key};
}

sub set {
    my ($self, $key, $value) = @_;
    $self->{$key} = $value;
}

sub add_contact {
    my ($self, $value) = @_;
    push @{$self->{'Contacts'}}, $value;
}

sub get_contacts {
    my ($self) = @_;
    return @{$self->{'Contacts'}};
}

sub add_tech {
    my ($self, $value) = @_;
    push @{$self->{'Techs'}}, $value;
}

sub get_techs {
    my ($self) = @_;
    return @{$self->{'Techs'}};
}

sub add_war {
    my ($self, $value) = @_;
    push @{$self->{'AtWars'}}, $value;
}

sub get_wars {
    my ($self) = @_;
    return @{$self->{'AtWars'}};
}

sub add_peace {
    my ($self, $value) = @_;
    push @{$self->{'PermanentWarPeaces'}}, $value;
}

sub get_peaces {
    my ($self) = @_;
    return @{$self->{'PermanentWarPeaces'}};
}

sub add_ob {
    my ($self, $value) = @_;
    push @{$self->{'OpenBordersWithTeams'}}, $value;
}

sub get_obs {
    my ($self) = @_;
    return @{$self->{'OpenBordersWithTeams'}};
}

sub add_pact {
    my ($self, $value) = @_;
    push @{$self->{'DefensivePactWithTeams'}}, $value;
}

sub get_pacts {
    my ($self) = @_;
    return @{$self->{'DefensivePactWithTeams'}};
}

sub add_project {
    my ($self, $value) = @_;
    push @{$self->{'ProjectTypes'}}, $value;
}

sub get_projects {
    my ($self) = @_;
    return @{$self->{'ProjectTypes'}};
}

sub parse {
    my ($self, $fh) = @_;
    
    # begin unit is already found
    while (1) {
        my $line = <$fh>;
        next if $line !~ /\w/;
        next if $line =~ /^\s*#/;
        return if $line =~ /EndTeam/i;
        chomp $line;
        $line =~ s/^\s*//;
        $line =~ s/\s*$//;
        
        my ($name, $value) = split '=', $line;
        
        if ($name eq 'Tech') {
            $self->add_tech($value);
        }
        elsif ($name eq 'ContactWithTeam') {
            $self->add_contact($value);
        }
        elsif ($name eq 'AtWar') {
            $self->add_war($value);
        }
        elsif ($name eq 'PermanentWarPeace') {
            $self->add_peace($value);
        }
        elsif ($name eq 'OpenBordersWithTeam') {
            $self->add_ob($value);
        }
        elsif ($name eq 'DefensivePactWithTeam') {
            $self->add_pact($value);
        }
        elsif ($name eq 'ProjectType') {
            $self->add_project($value);
        }
        else {
            $self->set($name, $value);
        }
    }
}

sub write {
    my ($self, $fh) = @_;
    print $fh "BeginTeam\n";
    
    write_block_data($self, $fh, 1, 'TeamID');
    
    my @techs = $self->get_techs();
    foreach my $t (@techs) {
        $self->set('Tech', $t);
        write_block_data($self, $fh, 1, 'Tech');
    }
    
    my @contacts = $self->get_contacts();
    foreach my $c (@contacts) {
        $self->set('ContactWithTeam', $c);
        write_block_data($self, $fh, 1, 'ContactWithTeam');
    }
    
    my @wars = $self->get_wars();
    foreach my $w (@wars) {
        $self->set('AtWar', $w);
        write_block_data($self, $fh, 1, 'AtWar');
    }
    
    my @peaces = $self->get_peaces();
    foreach my $p (@peaces) {
        $self->set('PermanentWarPeace', $p);
        write_block_data($self, $fh, 1, 'PermanentWarPeace');
    }
    
    my @obs = $self->get_obs();
    foreach my $o (@obs) {
        $self->set('OpenBordersWithTeam', $o);
        write_block_data($self, $fh, 1, 'OpenBordersWithTeam');
    }
    
    my @pacts = $self->get_pacts();
    foreach my $p (@pacts) {
        $self->set('DefensivePactWithTeam', $p);
        write_block_data($self, $fh, 1, 'DefensivePactWithTeam');
    }
    
    my @projects = $self->get_projects();
    foreach my $p (@projects) {
        $self->set('ProjectType', $p);
        write_block_data($self, $fh, 1, 'ProjectType');
    }
    
    write_block_data($self, $fh, 1, 'RevealMap');
        
    print $fh "EndTeam\n";
}


1;