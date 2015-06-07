package Civ4MapCad::Commands::Mask;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(import_mask_from_ascii new_mask_from_shape mask_difference mask_union mask_intersect mask_invert mask_threshold);

use Civ4MapCad::Object::Mask;
use Civ4MapCad::ParamParser;

sub new_mask_from_shape {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'shape_params' => 1,
        'has_result' => 'mask',
        'required' => ['shape', 'int', 'int'],
        'optional' => {
            'width' => 0,
            'height' => 0
        }
    });
    return -1 if $pparams->{'error'};
    
    my ($shape, $width, $height) = $pparams->get_required;
    my $shape_params = $pparams->get_shape_params();
    
    $shape_params->{'width'} = $width;
    $shape_params->{'height'} = $height;
    
    if (($width == 0) or ($height == 0)) {
        $state->report_error("new mask dimensions must have non-zero width and height.");
        return -1;
    }
    
    my $result_name = $pparams->get_result_name();
    $state->set_variable($result_name, 'mask', Civ4MapCad::Mask->new_from_shape($pparams->{'width'}, $pparams->{'height'}, $shape, $shape_params));
    
    return 1;
}

sub import_mask_from_ascii {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['filename'],
        'has_result' => 'mask',
        'optional' => {
            'mask' => '',
            'weights' => {'.' => 1, ' ' => 0},
        }
    });
    return -1 if $pparams->{'error'};
    
    my $filename = $pparams->get_required();
    my $ret = open (my $test, $filename) || 0;
    unless ($ret) {
        $state->report_error("cannot import ascii shape from '$filename': $!");
        return -1;
    }
    close $test;
    
    my $result_name = $pparams->get_result_name();
    $state->set_variable($result_name, 'mask', Civ4MapCad::Mask->new_from_ascii($filename, $pparams->{'weights'}));
    
    return 1;
}

sub mask_difference {
    my ($state, @params) = @_;
    return _two_op($state, sub { my ($t, @r) = @_; return $t->difference(@r) }, @params);
}

sub mask_union {
    my ($state, @params) = @_;
    return _two_op($state, sub { my ($t, @r) = @_; return $t->union(@r) }, @params);
}

sub mask_intersect {
    my ($state, @params) = @_;
    return _two_op($state, sub { my ($t, @r) = @_; return $t->intersection(@r) }, @params);
}

sub mask_invert {
    my ($state, @params) = @_;
    return _one_op($state, sub { my ($t, @r) = @_; return $t->invert(@r) }, @params);
}

sub mask_threshold {
    my ($state, @params) = @_;
    return _one_op($state, sub { my ($t, @r) = @_; return $t->threshold(@r) }, @params);
}

sub _one_op {
    my ($state, $sub, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'mask',
        'required' => ['mask']
    });
    return -1 if $pparams->{'error'};
    
    my $target = $pparams->get_required;
    my $result = $sub->($target);
    my $result_name = $pparams->get_result_name();
    $state->set_variable($result_name, 'mask', $result);
    
    return 1;
}

sub _two_op {
    my ($state, $sub, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'mask',
        'required' => ['mask', 'mask'],
        'optional' => {
            'offsetX' => 0,
            'offsetY' => 0
        }
    });
    return -1 if $pparams->{'error'};
    
    my ($target, $with) = $pparams->get_required();
    
    my $offsetX = $pparams->get_named('offsetX');
    my $offsetY = $pparams->get_named('offsetY');
    
    my $result = $sub->($target, $with, $offsetX, $offsetY);
    
    my $result_name = $pparams->get_result_name();
    $state->set_variable($result_name, 'mask', $result);
    
    return 1;
}

sub generate_layer {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'layer',
        'required' => ['mask']
    });
    
    
}

sub modify_layer {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'has_result' => 'layer',
        'required' => ['mask']
    });
    
}

sub cutout_layer {

}

1;