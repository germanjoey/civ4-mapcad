package Civ4MapCad::Commands::Config;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(set_output_dir set_mod write_log write_config);

use Config::General;
use Civ4MapCad::Util qw(find_max_players);

use Civ4MapCad::ParamParser;

# write_config is also a command

sub set_output_dir {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['str'],
        'optional' => {
            'delete_existing' => 0
        }
    });
    return -1 if $pparams->has_error;
    
    my $delete_existing = $pparams->get_named('delete_existing');
    my ($directory) = $pparams->get_required();
    
    $main::config{'output_dir'} = $directory;
}

sub set_mod {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['str'],
    });
    return -1 if $pparams->has_error;
    
    my ($mod) = $pparams->get_required();
    my $max = find_max_players($mod);
    
    if ($max == -1) {
        $state->error("Unknown mod type: '$mod'.");
        return;
    }
    elsif ($max == $main::config{'max_players'}) {
        $state->warning("Max players is already set to '$max'.");
        return;
    }
    
    foreach my $group (@{ $state->{'group'} }) {
        foreach my $layer (@{ $group->get_layers() }) {
            $layer->set_players($max);
        }
    }
    
    return 1;
}

sub write_log {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'optional' => {
            'filename' => 'log.civ4mc',
            'delete_existing' => 0
        }
    });
    return -1 if $pparams->has_error;
    
    my $delete_existing = $pparams->get_named('delete_existing');
    my $filename = $pparams->get_named('filename');
    
    if ((-e $filename) and ($delete_existing ne '0')) {
        open (my $log, '>', $filename) or die $!;
        print join("\n", $state->get_log());
        close $log;
    }
    
}
