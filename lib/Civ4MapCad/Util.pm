package Civ4MapCad::Util;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(write_block_data deepcopy write_config slurp);

use Data::Dumper;
use Config::General qw(SaveConfig);

sub write_block_data {
    my ($obj, $fh, $indent, $name1, $name2) = @_;
    
    if (exists $obj->{$name1}) {
        
        print $fh "\t" x $indent;
        print $fh  $name1, "=";
        print $fh  $obj->get($name1, $name2);
            
        if (defined($name2) and (exists $obj->{$name2})) {
            print $fh  ", ";
            print $fh  $name2, "=", $obj->get($name2);
        }
        print $fh  "\n";
    }
}

# for some reason, objects that get repeatedly copied get fucked up somehow
sub deepcopy {
    my ($v) = @_;
    
    if (ref($v) =~ /Group/) {
        eval "use Civ4MapCad::Object::Group; "; # delay import to prevent recursive import goofiness
        my $copy = Civ4MapCad::Object::Group->new_blank($v->get_width(), $v->get_height());
        foreach my $k (keys %$v) {
            $copy->{$k} = deepcopy($v->{$k});
        }
        return $copy;
    }
    elsif (ref($v) =~ /Layer/) {
        my $width = $v->get_width();
        my $height = $v->get_height();
        
        eval " use Civ4MapCad::Object::Layer; "; # delay import to prevent recursive import goofiness
        my $copy = Civ4MapCad::Object::Layer->new_default($v->get_name(), $width, $height);
        
        foreach my $k (keys %$v) {
            next if $k eq 'member_of';
            $copy->{$k} = deepcopy($v->{$k});
        }
        
        $copy->{'member_of'} = $v->{'member_of'};
        return $copy;
    }
    
    my $d = Data::Dumper->new([$v]);
    $d->Purity(1)->Terse(1)->Deepcopy(1);
    
    no strict;
    my $x = eval $d->Dump;
    
    return $x;
}

sub write_config {
    my %config = deepcopy(%main::config);
    delete $config{'max_players'};
    SaveConfig('def/config.cfg', \%config);
}

sub slurp {
    my $file = shift;
    open my $fh, '<', $file or die;
    local $/ = undef;
    my $cont = <$fh>;
    close $fh;
    return $cont;
}

1;
