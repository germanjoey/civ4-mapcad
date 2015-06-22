package Civ4MapCad::Commands::TopLevel;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(set_output_dir write_log);

use Civ4MapCad::ParamParser;

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
