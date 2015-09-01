package Civ4MapCad::Commands::Balance;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(balance_report);

use Civ4MapCad::Util qw(deepcopy);
use Civ4MapCad::ParamParser;

my $balance_report_help_text = qq[

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
            'balance_config' => 'def/balance_config.cfg',
            'sim_to_turn' => 155,
            'heatmap' => ['bfc_value'],
        },
        'optional_descriptions' => {
            'iterations' => 'Number of times to simulate',
            'tuning_iterations' => 'Number of extra times to simulate to set the estimate for contention',
            'balance_config' => 'configuration file for all the various constants used in the allocation algorithm.',
            'sim_to_turn' => 'Ending turn of each simulation. It can be a good idea to check the status of the map at various different endpoints',
            'heatmap' => "Creates a mask from some attribute of the mask and then immediately makes an html view of it, as if 'debug_mask' was used. Can be specified multiple times to create multiple heatmaps. If a name is preceded by a '+', then the heatmap will be appended to the current debug output, as if --add_to_existing were used." 
        },
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;

    my $result_name = $pparams->get_result_name();
    my ($group) = $pparams->get_required();
    my $copy = deepcopy($group);
    
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
    
    
    #system("perl balance.pl $in_filename $options ");
    
    return 1;
}