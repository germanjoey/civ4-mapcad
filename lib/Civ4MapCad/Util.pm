package Civ4MapCad::Util;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(write_block_data deepcopy report_error report_warning list find_max_players write_config);

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

sub list {
    my ($state, @items) = @_;
    
    print "\n  ";
    print join ("\n  ", @items);
    print "\n\n";
    
    return 1;
}

sub deepcopy {
    my ($v) = @_;
    my $d = Data::Dumper->new([$v]);
    $d->Purity(1)->Terse(1)->Deepcopy(1);
    
    no strict;
    my $x = eval $d->Dump;
}

sub find_max_players {
    my ($mod) = @_;

    if ($mod eq 'rtr') {
        return 40;
    }
    elsif ($mod eq 'none') {
        return 18;
    }
    else {
        return -1;
    }
}

sub write_config {
    my %config = deepcopy(%main::config);
    delete $config{'max_players'};
    SaveConfig('def/config.cfg', \%config);
}

1;
