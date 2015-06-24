package Civ4MapCad::Commands::Weight;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(load_terrain new_weight_table import_weight_table_from_file);

use Civ4MapCad::ParamParser;
use Civ4MapCad::Object::Weight;
use Config::General;

sub load_terrain {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['str']
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
 
sub new_weight_table {
    my ($state, @params) = @_;
    return _process_weight_import($state, @params);
}
 
sub import_weight_table_from_file {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['str'],
        'has_result' => 'weight'
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
        my ($operator, $weight, $target) = $pair =~ /^(\>|\<|=|\<=|\>=)([10]|0\.\d+)(?:\=\>)(\%?\w+)$/;
       
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
   
    $state->set_variable($result_name, 'weight', Civ4MapCad::Object::Weight->new_from_pairs($state->{'weight'}, @weights));
    return 1;
}

1;
