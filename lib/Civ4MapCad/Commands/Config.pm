package Civ4MapCad::Commands::Config;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(set_output_dir set_mod write_log history);

use Config::General;
use Civ4MapCad::Util qw(find_max_players);

use Civ4MapCad::ParamParser;

my $set_output_dir_help_text = qq[
    'set_output_dir' sets the default output directory for other commands, e.g. export_sims.
];
sub set_output_dir {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['str'],
        'required_descriptions' => ['directory path'],
        'help_text' => $set_output_dir_help_text,
        'optional' => {
            'delete_existing' => 'false'
        }
    });
    return -1 if $pparams->has_error;
    
    my $delete_existing = $pparams->get_named('delete_existing');
    my ($directory) = $pparams->get_required();
    
    $main::config{'output_dir'} = $directory;
    
    return 1;
}

my $set_mod_help_text = qq[
    'set_mod' sets the current mod to set the maximum number of players recognized by the save. This value can be either "RtR" (which allows a maximum of 40 players) or "none" (maximum allowed is 18 players). All existing groups will be converted to this mod and any newly created/imported groups will be automatically converted as well.
];
sub set_mod {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['str'],
        'required_descriptions' => ['mod name'],
        'help_text' => $set_mod_help_text
    });
    return -1 if $pparams->has_error;
    
    my ($mod) = $pparams->get_required();
    my $max = find_max_players($mod);
    
    if ($max == -1) {
        $state->report_error("Unknown mod type: '$mod'.");
        return -1;
    }
    elsif ($max == $main::config{'max_players'}) {
        $state->report_warning("Max players is already set to '$max'.");
        return 1;
    }
    
    my @groups = sort keys %{ $state->{'group'} };
    if (@groups > 0) {
        my @modified;
        foreach my $group_name (@groups) {
            my $group = $state->{'group'}{$group_name};
            push @modified, "* Setting $group_name to $max players.";
            
            foreach my $layer ($group->get_layers()) {
                $layer->set_max_num_players($max);
            }
        }
        
        $state->list( @modified );
    }
    
    $main::config{'max_players'} = $max;
    return 1;
}

my $write_log_help_text = qq[
    'write_log' writes the current history of all commands to a 'log.civ4mc' text file in the base directory. Commands executed in scripts are not included.
];
sub write_log {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'help_text' => $write_log_help_text,
        'optional' => {
            'filename' => 'log.civ4mc'
        }
    });
    return -1 if $pparams->has_error;
    
    my $filename = $pparams->get_named('filename');
    
    open (my $log, '>', $filename) or die $!;
    print $log join("\n", $state->get_log());
    close $log;
    
    return 1;
}

my $history_help_text = qq[
    Prints a list of all previous commands back to the command line.
];
sub history {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'help_text' => $history_help_text
    });
    return -1 if $pparams->has_error;
    
    my @log;
    my $i = 0;
    foreach my $cmd ($state->get_log()) {
        $i ++;
        push @log, "  $i: $cmd";
    }
    
    $state->list( @log );
    return 1;
}

1;