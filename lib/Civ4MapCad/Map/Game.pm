package Civ4MapCad::Map::Game;

use strict;
use warnings;

our @fields = qw(Era Speed Calendar GameTurn MaxTurns MaxCityElimination NumAdvancedStartPoints TargetScore StartYear Description ModPath);
our %field_names;
@field_names{@fields} = (1) x @fields;

use Civ4MapCad::Util qw(write_block_data);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    
    my $obj = bless {}, $class;
    $obj->{'Victories'} = [];
    $obj->{'Options'} = [];
    $obj->{'MPOptions'} = [];
    $obj->{'ForceControls'} = [];
    
    return $obj;
}

sub new_default {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $obj = bless {}, $class;
    
    $obj->default();
    return $obj;
}

sub default {
    my ($self) = @_;
    $self->clear();
    
    $self->set('Era', 'ERA_ANCIENT');
    $self->set('Speed', 'GAMESPEED_NORMAL');
    $self->set('Calendar', 'CALENDAR_DEFAULT');
    
    $self->add_option('GAMEOPTION_LEAD_ANY_CIV');
    $self->add_option('GAMEOPTION_NO_VASSAL_STATES');
    $self->add_option('GAMEOPTION_NO_GOODY_HUTS');
    $self->add_option('GAMEOPTION_NO_EVENTS');
    
    $self->add_victory('VICTORY_TIME');
    $self->add_victory('VICTORY_CONQUEST');
    $self->add_victory('VICTORY_DOMINATION');
    $self->add_victory('VICTORY_CULTURAL');
    $self->add_victory('VICTORY_SPACE_RACE');
    $self->add_victory('VICTORY_DIPLOMATIC');
    
    $self->set('GameTurn', 0);
    $self->set('MaxTurns', 500);
    $self->set('MaxCityElimination', 0);
    $self->set('NumAdvancedStartPoints', 600);
    $self->set('TargetScore', 0);
    $self->set('StartYear', -4000);
    $self->set('Description', '');
    $self->set('ModPath', '');
}

sub clear {
    my ($self) = @_;
    
    delete $self->{$_} foreach (@fields);

    $self->{'Victories'} = [];
    $self->{'Options'} = [];
    $self->{'MPOptions'} = [];
    $self->{'ForceControls'} = [];
}

sub get {
    my ($self, $key) = @_;
    return $self->{$key};
}

sub set {
    my ($self, $key, $value) = @_;
    $self->{$key} = $value;
}

sub add_victory {
    my ($self, $value) = @_;
    push @{$self->{'Victories'}}, $value;
}

sub remove_victory {
    my ($self, $value) = @_;
    
    my @kept;
    foreach my $victory (@{$self->{'Victories'}}) {
        push @kept, $victory if $victory ne $value;
    }
    
    $self->{'Victories'} = \@kept;
}

sub strip_victories {
    my ($self) = @_;
    
    $self->remove_victory('VICTORY_CONQUEST');
    $self->remove_victory('VICTORY_DOMINATION');
    $self->remove_victory('VICTORY_CULTURAL');
    $self->remove_victory('VICTORY_SPACE_RACE');
    $self->remove_victory('VICTORY_DIPLOMATIC');
}

sub get_victories {
    my ($self, $key) = @_;
    return @{$self->{'Victories'}};
}

sub add_mpoption {
    my ($self, $value) = @_;
    push @{$self->{'MPOptions'}}, $value;
}

sub get_mpoptions {
    my ($self, $key) = @_;
    return @{$self->{'MPOptions'}};
}

sub add_option {
    my ($self, $value) = @_;
    push @{$self->{'Options'}}, $value;
}

sub get_options {
    my ($self, $key) = @_;
    return @{$self->{'Options'}};
}

sub add_force_option {
    my ($self, $value) = @_;
    push @{$self->{'ForceControls'}}, $value;
}

sub get_force_options {
    my ($self, $key) = @_;
    return @{$self->{'ForceControls'}};
}

sub parse {
    my ($self, $fh) = @_;
    
    # begin unit is already found
    while (1) {
        my $line = <$fh>;
        next if $line !~ /\w/;
        next if $line =~ /^\s*#/;
        return if $line =~ /EndGame/i;
        chomp $line;
        $line =~ s/^\s*//;
        $line =~ s/\s*$//;
        
        my ($name, $value) = split '=', $line;
        
        if ($name eq 'Victory') {
            $self->add_victory($value);
        }
        elsif ($name eq 'Option') {
            $self->add_option($value);
        }
        elsif ($name eq 'ForceControl') {
            $self->add_force_option($value);
        }
        elsif ($name eq 'MPOption') {
            $self->add_mpoption($value);
        }
        else {
            $self->set($name, $value);
        }
    }
}

sub write {
    my ($self, $fh) = @_;
    print $fh "BeginGame\n";
    
    foreach my $field (@fields) {
        write_block_data($self, $fh, 1, $field);
        
        if ($field eq 'Calendar') {
            my @options = $self->get_options();
            foreach my $o (@options) {
                $self->set('Option', $o);
                write_block_data($self, $fh, 1, 'Option');
            }
            
            my @mpoptions = $self->get_mpoptions();
            foreach my $o (@mpoptions) {
                $self->set('MPOption', $o);
                write_block_data($self, $fh, 1, 'MPOption');
            }
            
            my @force_options = $self->get_force_options();
            foreach my $o (@force_options) {
                $self->set('ForceControl', $o);
                write_block_data($self, $fh, 1, 'ForceControl');
            }
            
            my @victories = $self->get_victories();
            foreach my $v (@victories) {
                $self->set('Victory', $v);
                write_block_data($self, $fh, 1, 'Victory');
            }
        }
    }
    
    print $fh "EndGame\n";
}


1;