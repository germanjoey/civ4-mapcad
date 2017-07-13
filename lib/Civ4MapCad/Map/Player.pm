package Civ4MapCad::Map::Player;

use strict;
use warnings;

our @fields = qw(Team LeaderType LeaderName CivDesc CivShortDesc CivAdjective FlagDecal WhiteFlag CivType Color ArtStyle PlayableCiv MinorNationStatus StartingGold StartingX StartingY StateReligion StartingEra RandomStartLocation Handicap);
our %field_names;
@field_names{@fields} = (1) x @fields;

use Civ4MapCad::Util qw(write_block_data);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $obj = bless {}, $class;
    
    $obj->{'Civics'} = [];
    return $obj;
}

sub new_default {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $obj = bless {}, $class;
    
    my $teamID = shift;
    $obj->set_default($teamID);
    return $obj;
}

sub set_default {
    my ($self, $teamID) = @_;
    $self->clear();
    $self->set('Team', $teamID);
    $self->set('LeaderType', 'NONE');
    $self->set('CivType', 'NONE');
    $self->set('Color', 'NONE');
    $self->set('ArtStyle', 'NONE');
    $self->set('Handicap', $main::state->{'config'}{'difficulty'});
}

sub clear {
    my ($self) = @_;
    delete $self->{$_} foreach (@fields);
    $self->{'Civics'} = [];
}

sub get {
    my ($self, $key) = @_;
    return $self->{$key};
}

sub set {
    my ($self, $key, $value) = @_;
    $self->{$key} = $value;
}

sub get_civics {
    my ($self) = @_;
    return @{$self->{'Civics'}};
}

sub add_civics {
    my ($self, $line) = @_;
    
    my ($civic_option, $civic) = split ' ', $line;
    $civic_option =~ s/,$//;
    my @civic_option_parts = split '=', $civic_option;
    my @civic_parts = split '=', $civic;
    
    push @{$self->{'Civics'}}, [$civic_option_parts[1], $civic_parts[1]];
}

sub parse {
    my ($self, $fh) = @_;
    
    # begin unit is already found
    while (1) {
        my $line = <$fh>;
        next if $line !~ /\w/;
        next if $line =~ /^\s*#/;
        return if $line =~ /EndPlayer/i;
        chomp $line;
        $line =~ s/^\s*//;
        $line =~ s/\s*$//;
        
        if ($line =~ /^CivicOption/i) {
            $self->add_civics($line);
        }
        
        elsif ($line =~ /^StartingX/) {
            my ($StartingX, $StartingY) = split ',', $line;
            my ($stX, $stXV) = split '=', $StartingX;
            my ($stY, $stYV) = split '=', $StartingY;
            $self->set('StartingX', $stXV);
            $self->set('StartingY', $stYV);
        }
        else {
            my ($name, $value) = split '=', $line;
            $self->set($name, $value);
        }
    }
}

sub writeout {
    my ($self, $fh) = @_;
    print $fh "BeginPlayer\n";
    
    foreach my $field (@fields) {
        next if $field eq 'StartingY';
        if ($field eq 'StartingX') {
            write_block_data($self, $fh, 1, 'StartingX', 'StartingY');
        }
        elsif ($field eq 'Handicap') {
            foreach my $civic ($self->get_civics()) {
                $self->set('CivicOption', $civic->[0]);
                $self->set('Civic', $civic->[1]);
                write_block_data($self, $fh, 1, 'CivicOption', 'Civic');
            }
        
            write_block_data($self, $fh, 1, $field);
        }
        else {
            write_block_data($self, $fh, 1, $field);
        }
        
    }
    
    print $fh "EndPlayer\n";
}

sub is_active {
    my ($self) = @_;
    
    return 1 if $self->{'LeaderType'} ne 'NONE';
    return 0;
}

sub set_from_data {
    my ($self, $data) = @_;
    
    my $teamID = $self->get('Team');
    $self->clear();
    
    # we don't expect every single field here, so only do these
    my @expected_fields = ('CivType', 'CivDesc', 'CivShortDesc', 'CivAdjective', 'Color', 'ArtStyle', 'PlayableCiv', 'WhiteFlag',
                           'MinorNationStatus', 'StartingX', 'StartingY', 'StateReligion', 'RandomStartLocation', 'FlagDecal');
    
    foreach my $key (@expected_fields) {
        $self->set($key, $data->{$key});
    }
            
    $self->set('Handicap', $main::state->{'config'}{'difficulty'});
    
    # assign a random leader for that civ
    my $leader_count = 0 + @{ $data->{'_LeaderType'} };
    my $rand_leader = int( $leader_count*rand(1) );
    $self->set('LeaderType', $data->{'_LeaderType'}[$rand_leader][0]);
    $self->set('LeaderName', $data->{'_LeaderType'}[$rand_leader][1]);
    
    # each civic will be formatted properly in the load_xml_data command
    foreach my $civic (@{ $data->{'_Civics'} }) {
        $self->add_civics($civic);
    }
    
    $self->set('Team', $teamID);
}

1;