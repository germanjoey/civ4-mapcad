package Civ4MapCad::Commands::List;
 
use strict;
use warnings;
 
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(list_shapes list_groups list_layers list_masks list_weights show_weights new_weight_table  dump_group dump_mask dump_layer);
 
use Config::General;

use Civ4MapCad::ParamParser;
use Civ4MapCad::Util qw(list);
 
sub list_shapes {
    my ($state, @params) = @_;
   
    list($state, keys %{$state->{'shape'}});
    return 1;
}
 
sub list_groups {
    my ($state, @params) = @_;
   
    list($state, keys %{$state->{'group'}});
    return 1;
}
 
sub list_layers {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group']
    });
    return -1 if $pparams->has_error;
    
    my ($group) = $pparams->get_required();
    list($state, $group->get_layer_names());
    
    return 1;
}
 
sub list_masks {
    my ($state, @params) = @_;
   
    list($state, keys %{$state->{'mask'}});
    return 1;
}
 
sub list_weights {
    my ($state, @params) = @_;
   
    list($state, keys %{$state->{'weight'}});
    return 1;
}
 
sub show_weights {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['weight'],
        'optional' => {
            'nested' => 0
        }
    });
    return -1 if $pparams->has_error;
    
    my ($weight) = $pparams->get_required();
    
    if ($pparams->{'nested'}) {
        die "TODO!";
        # TODO!
    }
    else {
        my @dep = map { "@$_" } @$weight;
        list($state, @dep);
    }
    
    return 1;
}

sub dump_group {
    my ($state, @params) = @_;
    
}

sub dump_mask {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['mask'],
        'optional' => {
            'full_values' => 0
        }
    });
    return -1 if $pparams->has_error;
    
    my ($mask) = $pparams->get_required();
    
    foreach my $xx (0..$mask->get_width()-1) {
        foreach my $yy (0..$mask->get_height()-1) {
            my $x = $mask->get_width() - 1 - $xx;
            my $y = $mask->get_height() - 1 - $yy;
            my $value = ($mask->{'canvas'}[$x][$y] > 0);
            print $value;
        }
        print "\n";
    }
}

sub dump_layer {

}

1;


