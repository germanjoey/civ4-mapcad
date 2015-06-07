package Civ4MapCad::Map::Unit;

our @fields = qw(UnitType UnitOwner UnitName Damage Level Experience FacingDirection UnitAIType PromotionType);
our %field_names;
@field_names{@fields} = (1) x @fields;

use Civ4MapCad::Util qw(write_block_data);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    
    my $obj = bless {}, $class;
    $obj->{'Promotions'} = [];
    
    return $obj;
}

sub add_promotion {
    my ($self, $val) = @_;
    push @{$self->{'promotions'}}, $val;
}

sub get_promotions {
    my ($self) = @_;
    return @{ $self->{'promotions'} };
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
    my ($self, $fh) = @_;
    
    # begin unit is already found
    while (1) {
        my $line = <$fh>;
        next if $line !~ /\w/;
        next if $line =~ /^\s*#/;
        return if $line =~ /EndUnit/i;
        chomp $line;
        $line =~ s/^\s*//;
        $line =~ s/\s*$//;
        
        my @pieces = split ',', $line;
        foreach my $piece (@pieces) {
            $piece =~ s/,$//;
            $piece =~ s/^\s*//;
            $piece =~ s/\s*$//;
            
            my ($name, $value) = split '=', $piece;
            
            if ($name eq 'PromotionType') {
                $self->add_promotion($value);
            }
            else {
                $self->set($name, $value);
            }
        }
    }
}

sub write {
    my ($self, $fh) = @_;
    print $fh "\tBeginUnit\n";
    
    write_block_data($self, $fh, 2, 'UnitType', 'UnitOwner');
    write_block_data($self, $fh, 2, 'UnitName');
    write_block_data($self, $fh, 2, 'Damage');
    write_block_data($self, $fh, 2, 'Level', 'Experience');
    
    my @promotions = $self->get_promotions();
    foreach my $promo (@promotions) {
        $self->set('PromotionType', $promo);
        write_block_data($self, $fh, 2, 'PromotionType');
    }
    
    write_block_data($self, $fh, 2, 'FacingDirection');
    write_block_data($self, $fh, 2, 'UnitAIType');
    
    print $fh "\tEndUnit\n";
}

1;