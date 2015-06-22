package Civ4MapCad::Util;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(write_block_data deepcopy report_error report_warning list);

use Data::Dumper;

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

1;
