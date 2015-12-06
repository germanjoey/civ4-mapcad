package Civ4MapCad::Commands::Balance;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(balance_report fix_map);

use Civ4MapCad::Util qw(deepcopy);
use Civ4MapCad::ParamParser;

# TODO: allow multiple heatmaps
my $balance_report_help_text = qq[
    Generates a balance report based on an MCMC land allocation algorithm.
];
sub balance_report {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to report on'],
        'help_text' => $balance_report_help_text,
        'optional' => {
            'iterations' => 100,
            'tuning_iterations' => 40,
            'balance_config' => 'def/balance.cfg',
            'sim_to_turn' => 145,
            'heatmap' => 'bfc_value',
        },
        'optional_descriptions' => {
            'iterations' => 'Number of times to simulate',
            'tuning_iterations' => 'Number of extra times to simulate to set the estimate for contention',
            'balance_config' => 'configuration file for all the various constants used in the allocation algorithm.',
            'sim_to_turn' => 'Ending turn of each simulation. It can be a good idea to check the status of the map at various different endpoints',
            'heatmap' => "Creates a mask from some attribute of the mask and then immediately makes an html view of it, as if 'debug_mask' was used. If a name is preceded by a '+', then the heatmap will be appended to the current debug output, as if --add_to_existing were used." 
        },
    });
    
    if ($pparams->{'help'} or $pparams->{'help_anyways'}) {
        system ("balance.pl --heatmap_options");
    }
    
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;

    my $result_name = $pparams->get_result_name();
    my ($group) = $pparams->get_required();
    my $copy = deepcopy($group);
    
    my $iterations = $pparams->get_named('iterations');
    my $tuning_iterations = $pparams->get_named('tuning_iterations');
    my $balance_config = $pparams->get_named('balance_config');
    my $sim_to_turn = $pparams->get_named('sim_to_turn');
    my $heatmap = $pparams->get_named('heatmap');
    
    if (! -e $balance_config) {
        $state->report_error(qq[The balance config file "$balance_config" does not exist!]);
        exit -1;
    }
    
    my $has_duplicate_owners = $group->has_duplicate_owners();
    my $ret = $copy->merge_all(1);
    if (exists $ret->{'error'}) {
        $state->report_error($ret->{'error_msg'});
        return -1;
    }
    
    my $output_dir = $state->{'config'}{'output_dir'};
    $copy->export($output_dir);
    
    my $group_name = $group->get_name();
    my $in_filename = $output_dir . "/" . $group_name . ".CivBeyondSwordWBSave";
    
    my $command_opt = "--input_filename $in_filename --balance_config $balance_config --to_turn $sim_to_turn --iterations $iterations --tuning_iterations $tuning_iterations --mod \"$state->{'mod'}\" --from_mapcad";
    $command_opt .= " --heatmap $heatmap";
    my $command = "perl balance.pl $command_opt";
    
    $state->list("Running command:\n", $command);
    system($command);
    
    return 1;
}

my $fix_map_help_text = qq[
    Fixes various map problems: rivers adjacent to coast, mismatched starting techs, removes floodplains that are not river adjacent,
    removes floodplains/oasis that are not on zero-yield tiles, removes jungles from peaks.
];
sub fix_map {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to fix'],
        'help_text' => $fix_map_help_text,
        'has_result' => 'group',
        'allow_implied_result' => 1,
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;

    my ($group) = $pparams->get_required();
    my ($result_name) = $pparams->get_result_name();
    my $copy = ($result_name eq $group->get_full_name()) ? $group : deepcopy($group);
    
    $copy->fix_map();
    $state->set_variable($result_name, 'group', $copy);
    
    return 1;
}

1;