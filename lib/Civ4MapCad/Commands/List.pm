package List;
 
use strict;
use warnings;
 
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(list_shapes list_groups list_layers list_masks list_weights show_weights new_weight_table import_weight_table_from_file);
 
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
    
    my $pparams = _process_params($state, \@params, {
        'required' => ['group']
    });
    
    my $group = $pparams->{'_required'}[0];
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
    
    my $weight = $pparams->{'_required'}[0];
    
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

1;
