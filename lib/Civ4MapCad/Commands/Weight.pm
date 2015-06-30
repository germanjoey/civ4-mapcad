package Civ4MapCad::Commands::Weight;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(load_terrain new_weight_table import_weight_table_from_file evaluate_weight);

use Civ4MapCad::ParamParser;
use Civ4MapCad::Object::Weight;
use Config::General;

my $load_terrain_help_text = qq[
    The 'load_terrain' command imports terrain definitions (in the same format as a CivBeyondSwordWBSave) into
    as objects usable in Weight tables, that can then subsequently be used with Masks to actually create tiles.
    Please see def/base_terrain.cfg for an example terrain definition file, and the 'import_weight_table_from_file',
    'evaluate_weight', and 'generate_layer_from_mask' commands to better understand how terrain works with Weights and Masks.
];
sub load_terrain {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['str'],
        'help_text' => $load_terrain_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($filename) = $pparams->get_required();
    $filename =~ s/"//g;
    
    my $ret = open (my $test, $filename) || 0;
    unless ($ret) {
        $state->report_error("cannot import ascii shape from '$filename': $!");
        return -1;
    }
    close $test;
   
    my %terrain = Config::General->new($filename)->getall();
   
    foreach my $name (keys %terrain) {
        $state->set_variable($name, 'terrain', $terrain{$name});
    }
   
    return 1;
}

# this command has custom parsing, so we have to write out the format by hand too
my $new_weight_table_help_text = qq[
  Command Format: 
  
    new_weight_table >= float => result, [>= float => result,] => %weightname

  The 'new_weight_table' command creates a new Weight Table on the command
  line. It's really only suited for short and simple tables with just a couple
  choices.  For anything more complex than that, please see the
  'import_weight_table_from_file' command.
];
sub new_weight_table {
    my ($state, @params) = @_;
    
    if ((@params == 1) and ($params[0] eq '--help')) {
        print $new_weight_table_help_text, "\n";
        return 1;
    }
    
    my $result = pop @params;
    my $op = pop @params;
    
    my @quadedparams = (""); my $i=0;
    while (1) {
        my $param = shift @params;
        last unless defined $param;
        
        if ($i == 4) {
            $i = 0;
            push @quadedparams, "";
        }
        
        $quadedparams[-1] .= " $param";
        $i ++;
    }
    
    if ($i != 4) {
        $state->report_error("An irregular number of items was found in the parameter list!");
        print "  Command format:\n    new_weight_table >= float => result, [>= float => result,] => %weightname\n\n";
        return -1;
    }
    
    return _process_weight_import($state, @quadedparams, $op, $result);
}

my $import_weight_table_from_file_help_text = qq[
  The 'import_weight_table_from_file' command creates a new Weight Table from a definition described in
  a file. In short, it follows a format of "operator threshold => result". The result can be either be a
  terrain or another already-existing Weight Table, the threshold should be a floating point number,
  and the operator should be either '==' or '>='. See the 'evaluate_weight' command for a description
  of how Weights Tables are evaluated, 'generate_layer_from_mask' for how Weights Tables are used to
  generate actual tiles with Masks, or the 'Masks and Filters' section of the html documentation for
  more information on Weight Tables in general.
];
sub import_weight_table_from_file {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['str'],
        'has_result' => 'weight',
        'help_text' => $import_weight_table_from_file_help_text
    });
    return -1 if $pparams->has_error;

    my ($filename) = $pparams->get_required();
    $filename =~ s/"//g;
    
    my $result_name = $pparams->get_result_name();
    
    my $ret = open(my $weights, $filename) || 0;
    unless ($ret) {
        $state->report_error("cannot open file: $!");
        return -1;
    }

    my @lines = <$weights>;
    close $weights;
    
    my @proc_lines;
    foreach my $line (@lines) {
        chomp $line;
        next if $line =~ /\s*#/;
        next unless $line =~ /\w/;
        push @proc_lines, $line;
    }
    
    return _process_weight_import($state, @proc_lines, "=>", $result_name);
}
 
# this has a special syntax, so we can't use _process_params here
sub _process_weight_import {
    my ($state, @params) = @_;
    
    my $result_name = pop @params;
    my $operator = pop @params;
   
    if (($operator ne '=>') and ($result_name !~ /\%\w+/)) {
        $state->report_error("result not correctly specified.");
        return -1;
    }
   
    # reformat the remaining params as kv_pairs to account for weird spacing or forgotten commas or whatever
    my $comma_list = '';
    foreach my $item (@params) {
        $comma_list .= "$item,";
    }
    $comma_list =~ s/\s//g;
    $comma_list =~ s/,+/,/g;
    $comma_list =~ s/,$//;
    my @kv_pairs = split ",", $comma_list;
    
    my @weights;
    for my $pair (@kv_pairs) {
        # e.g.
        # >= 1   => grass,
        # >= 0.8 => grass_hill,
        # >= 0.6 => plains_hill
        my ($operator, $weight, $target) = $pair =~ /^(\>|\<|=|\<=|\>=)([10]|0\.\d+)(?:\=\>)(\%?\w+)(?:,)?$/;
       
        unless (defined($weight) and defined($operator) and defined($target)) {
            $state->report_error("problem parsing weight definition '$pair' in weight definition for '$result_name'.");
            return -1;
        }
        
        if ($target =~ /^\%/) {
            if (! exists $state->{'weight'}{$target}) {
                $state->report_error("weight target '$target' is not defined in weight definition for '$result_name'.");
                return -1;
            }
        }
        elsif (! exists $state->{'terrain'}{$target}) {
            $state->report_error("weight target '$target' is not known in weight definition for '$result_name'.");
            return -1;
        }
       
        push @weights, [$operator, $weight, $target];
    }
    
    my $obj = Civ4MapCad::Object::Weight->new_from_pairs(@weights);
    $state->set_variable($result_name, 'weight', $obj);
    return 1;
}

my $evaluate_weight_help_text = "
   The 'evaluate_weight' command returns the result of a Weight Table were it to be evaluated with a floating point value,
   as if that value were the coordinate of a mask. Thus, that value needs to be between 0 and 1. 'evaluate_weight' is only
   intended to be a debugging command; please see the Mask-related commands, e.g. 'generate_layer_from_mask',
   'modify_layer_from_mask', for actually using weights to generate/modify tiles. 
";
sub evaluate_weight {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['weight', 'float'],
        'help_text' => $evaluate_weight_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($weight, $value) = $pparams->get_required();
    my $result = $weight->evaluate($state, $value);
    $state->list($result);
    
    return 1;
}

1;
