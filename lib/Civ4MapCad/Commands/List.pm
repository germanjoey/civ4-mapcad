package Civ4MapCad::Commands::List;
 
use strict;
use warnings;
 
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(list_shapes list_groups list_layers list_masks list_weights show_difficulty find_starts
                    list_terrain list_civs list_leaders list_colors list_techs list_traits _describe_terrain);

use Civ4MapCad::ParamParser;
use Civ4MapCad::Util qw(deepcopy slurp);
use Civ4MapCad::Dump qw(dump_out dump_framework dump_single_layer);

my $list_shapes_help_text = qq[
  Command Format: 
  
    list_shapes search_term

  Description:
  
  The search_term is optional; if not supplied, all shapes will be listed.
];
sub list_shapes {
    my ($state, @params) = @_;
    
    if ((@params == 1) and ($params[0] eq '--help')) {
        $state->buffer_bar();
        print $list_shapes_help_text, "\n";
        $state->register_print();
        return 1;
    }
    
    my @shape_names = sort keys %{$state->{'shape'}};
    if (@params == 1) {
        @shape_names = grep { $_ =~ /\Q$params[0]\E/ } @shape_names;
    }
    elsif (@params > 0) {
        $state->buffer_bar();
        print $list_shapes_help_text, "\n";
        $state->register_print();
        return -1;
    }
    
    my @full;
    foreach my $shape_name (@shape_names) {
        my $description = $shape_name;
    
        foreach my $param (keys %{ $state->{'shape_param'}{$shape_name} }) { 
            if ($state->{'shape_param'}{$shape_name}{$param} =~ /\-?\d+\.\d+/) {
                $description .= " --$param float";
            }
            else {
                $description .= " --$param int";
            }
        }
        
        push @full, $description
    }
    
    if (@full == 0) {
        @full = ("None found.");
        @full = ("None found matching description '$params[0]'.") if @params == 1;
    }
   
    $state->list( @full );
    return 1;
}

my $list_groups_help_text = qq[
  Command Format: 
  
    list_groups search_term

  Description:
  
  The search_term is optional; if not supplied, all groups will be listed.
];
sub list_groups {
    my ($state, @params) = @_;
   
    if ((@params == 1) and ($params[0] eq '--help')) {
        $state->buffer_bar();
        print $list_groups_help_text, "\n";
        $state->register_print();
        return 1;
    }
    
    my @group_names = sort keys %{$state->{'group'}};
    if (@params == 1) {
        @group_names = grep { $_ =~ /\Q$params[0]\E/ } @group_names;
    }
    elsif (@params > 0) {
        $state->buffer_bar();
        print $list_groups_help_text, "\n";
        $state->register_print();
        return -1;
    }
    
    my @full;
    foreach my $group_name (@group_names) {
        my $group = $state->{'group'}{$group_name};
        my $description = _group_description($group);
        push @full, $description;
    }
    
    if (@full == 0) {
        @full = ("None found.");
        @full = ("None found matching description '$params[0]'.") if @params == 1;
    }
    
    $state->list( @full );
    return 1;
}

sub _group_description {
    my ($group) = @_;

    my $description = '$' . $group->get_name() . " (size: " . $group->get_width() . ' x ' . $group->get_height() . ")";
    $description .= ', ' if $group->wrapsX() or $group->wrapsY();
    $description .= 'wraps in X' if $group->wrapsX();
    $description .= ' and ' if $group->wrapsX() and $group->wrapsY();
    $description .= 'wraps in Y' if $group->wrapsY();
    
    return $description;
}
 
my $list_layers_help_text = qq[
    Lists all layers of a group by priority.
];
sub list_layers {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to describe'],
        'help_text' => $list_layers_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($group) = $pparams->get_required();
    my $group_description = _group_description($group);
    
    my @layers;
    push @layers, "$group_description\n";
    push @layers, "Layers:\n";
    
    foreach my $layer ($group->get_layers()) {
        my $layer_name = $layer->get_name();
        my $priority = 1 + $group->{'max_priority'} - $group->get_layer_priority($layer_name);
        my $moved = sprintf "moved to %d,%d from group origin", $layer->get_offsetX(), $layer->get_offsetY();
        $moved = "aligned with group origin" if ($layer->get_offsetX() == 0) and ($layer->get_offsetY() == 0);
        my $description = sprintf "  priority %s, %s (size: %d x %d), $moved", $priority, $layer->get_name(), $layer->get_width(), $layer->get_height();
        push @layers, $description;
    }
    
    push @layers, "\n  (higher priority numbers means those layers are \"above\" the others).";
    
    $state->list( @layers );
    return 1;
}

my $list_masks_help_text = qq[
  Command Format: 
  
    list_masks search_term

  Description:
  
  The search_term is optional; if not supplied, all masks will be listed.
];
sub list_masks {
    my ($state, @params) = @_;
   
    if ((@params == 1) and ($params[0] eq '--help')) {
        $state->buffer_bar();
        print $list_masks_help_text, "\n";
        $state->register_print();
        return 1;
    }
    
    my @mask_names = sort keys %{$state->{'mask'}};
    if (@params == 1) {
        @mask_names = grep { $_ =~ /\Q$params[0]\E/ } @mask_names;
    }
    elsif (@params > 0) {
        $state->buffer_bar();
        print $list_masks_help_text, "\n";
        $state->register_print();
        return -1;
    }
    
    my @full;
    foreach my $mask_name (@mask_names) {
        my $mask = $state->{'mask'}{$mask_name};
        my $description = sprintf "%s (size: %d x %d)", $mask_name, $mask->get_width(), $mask->get_height();
        push @full, $description;
    }
    
    if (@full == 0) {
        @full = ("None found.");
        @full = ("None found matching description '$params[0]'.") if @params == 1;
    }
    
    $state->list( @full );
    return 1;
}

my $list_terrain_help_text = qq[
  Command Format: 
  
    list_terrain search_term

  Description:
  
  The search_term is optional; if not supplied, all terrain will be listed.
];
sub list_terrain {
    my ($state, @params) = @_;
   
    if ((@params == 1) and ($params[0] eq '--help')) {
        $state->buffer_bar();
        print $list_terrain_help_text, "\n";
        $state->register_print();
        return 1;
    }
    
    my @terrain_names = sort keys %{$state->{'terrain'}};
    if (@params == 1) {
        @terrain_names = grep { $_ =~ /\Q$params[0]\E/ } @terrain_names;
        
        my @full;
        foreach my $terrain_name (@terrain_names) {
            push @full, $terrain_name;
            push @full, _describe_terrain($state->{'terrain'}{$terrain_name});
            $full[-1] .= "\n";
        }
        
        chomp $full[$#full] if @full > 0;
        @terrain_names = @full;
    }
    elsif (@params > 0) {
        $state->buffer_bar();
        print $list_terrain_help_text, "\n";
        $state->register_print();
        return -1;
    }
    
    if (@terrain_names == 0) {
        @terrain_names = ("None found.");
        @terrain_names = ("None found matching description '$params[0]'.") if @params == 1;
    }
    
    $state->list( @terrain_names );
    return 1;
}

sub _describe_terrain {
    my ($terrain) = @_;
    my @height_types = ('Peak', 'Hill', 'Flat', 'Water');
        
    my @full;
    foreach my $key (sort keys %$terrain) {
        push @full, "  $key = $terrain->{$key}";
        
        if ($key eq 'PlotType') {
            my $height = $terrain->{$key} + 0;
            $full[-1] .= " ($height_types[$height])";
        }
    }
    
    return @full;
}

my $list_weights_help_text = qq[
  Command Format: 
  
    list_weights search_term

  Description:
  
  The search_term is optional; if not supplied, all weights will be listed.
];
sub list_weights {
    my ($state, @params) = @_;
   
    if ((@params == 1) and ($params[0] eq '--help')) {
        $state->buffer_bar();
        print $list_weights_help_text, "\n";
        $state->register_print();
        return 1;
    }
    
    my @weight_names = sort keys %{$state->{'weight'}};
    if (@params == 1) {
        @weight_names = grep { $_ =~ /\Q$params[0]\E/ } @weight_names;
    }
    elsif (@params > 0) {
        $state->buffer_bar();
        print $list_weights_help_text, "\n";
        $state->register_print();
        return -1;
    }
    
    my @full;
    foreach my $weight_name (@weight_names) {
        my $weight = $state->{'weight'}{$weight_name};
        my @packed = @{ $weight->{'pairs'} };
        my @flat = $weight->flatten(1);
        
        my $description;
        if (@packed == @flat) {
            $description = sprintf "%s, %d entries", $weight_name, @packed+0;
        }
        else {
            $description = sprintf "%s, %d entries packed, %d entries flat", $weight_name, @packed+0, @flat+0;
        }
        
        push @full, $description;
    }
    
    if (@full == 0) {
        @full = ("None found.");
        @full = ("None found matching description '$params[0]'.") if @params == 1;
    }
    
    $state->list( @full );
    return 1;
}   
    
my $list_civs_help_text = qq[
    Lists all allowed civs. Optionally, add a civ name via '--civ' to see all default data associated with that civ.
];
sub list_civs {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'help_text' => $list_civs_help_text,
        'optional' => {
            'civ' => ''
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $civ_name_exact = $pparams->get_named("civ");
    my $civ_name = _format_civ_name($pparams->get_named("civ"));
    
    my $civ_name_proper = "$civ_name";
    $civ_name_proper =~ s/\s+/_/g;
    $civ_name_proper = 'CIVILIZATION_' . uc($civ_name_proper);

    if ($civ_name_exact ne '') {
        if (! exists $state->{'data'}{'civs'}{$civ_name_proper}) {
            $state->report_error("Unknown civ name: \"$civ_name_exact\".");
            return -1;
        }
        
        my $data = $state->{'data'}{'civs'}{$civ_name_proper};
        my @techs = map { _format_tech_name($_) } @{ $data->{'_Tech'} };
        my @leaders = map {_format_leader($state, $_->[0])} @{ $data->{'_Leaders'} };
        
        $state->buffer_bar();
        print "\n  $civ_name:\n";
        print "\n    Techs: ", join(", ", @techs), "\n";
        print "\n    Leaders: ", join(", ", @leaders), "\n";
        #print "\n    DefaultCivics:\n";
        #foreach my $key (sort @{ $data->{'_Civics'} }) {
        #    print "      $key\n";
        #}
        
        print "\n    Attributes:\n";
        foreach my $key (sort keys %$data) {
            next if $key =~ /^_/;
            my $value = $data->{$key};
            $value = _format_color_name($value) if $key eq 'Color';
            $value = _format_civ_name($value) if $key eq 'CivType';
            
            print "      $key=$value}\n";
        }
        
        print "\n";
        
        $state->register_print();
        return 1;
    }
    
    my @civs = map { _format_civ_name($_) } (sort keys %{ $state->{'data'}{'civs'} });
    
    $state->list( @civs );    
    return 1;     
}

my $list_colors_help_text = qq[
    List all valid color names. If '--color' is specified, only civs using that color by default will be listed.
];
sub list_colors {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'help_text' => $list_colors_help_text,
        'optional' => {
            'color' => ''
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $color_name_exact = $pparams->get_named("color");
    my $color_name = $pparams->get_named("color");
    $color_name = _format_color_name($color_name);
    my $color_name_proper = 'PLAYERCOLOR_' . uc("$color_name");
    $color_name_proper =~ s/\s+/_/g;
    
    if ($color_name_exact ne '') {
        if (! exists $state->{'data'}{'colors'}{$color_name_proper}) {
            $state->report_error("Unknown color name: \"$color_name_exact\".");
            return -1;
        }
    
        my $data = $state->{'data'}{'colors'}{$color_name_proper};
        $state->list("List of civs using color \"$color_name\":\n", map { _format_civ_name($_) } sort @$data);
        return 1;
    }
    
    my @colors = map { _format_color_name($_) } (sort keys %{ $state->{'data'}{'colors'} });
    $state->list( @colors );
    return 1;
}

my $list_techs_help_text = qq[
    List all valid starting techs. If '--tech' is specified, civs having that tech as a starting tech will be listed instead.
];
sub list_techs {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'help_text' => $list_techs_help_text,
        'optional' => {
            'tech' => ''
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $tech_name_exact = $pparams->get_named("tech");
    my $tech_name = $pparams->get_named("tech");
    $tech_name = _format_tech_name($tech_name);
    my $tech_name_proper = 'TECH_' . uc("$tech_name");
    $tech_name_proper =~ s/\s+/_/g;
    
    if ($tech_name_exact ne '') {
        if (! exists $state->{'data'}{'techs'}{$tech_name_proper}) {
            $state->report_error("Unknown tech name: \"$tech_name_exact\".");
            return -1;
        }
    
        my $data = $state->{'data'}{'techs'}{$tech_name_proper};
        
        my @civs;
        foreach my $civ (@$data) {
            my $other = _find_other_techs_name($state, $tech_name_proper, $civ);
            push @civs, _format_civ_name($civ) . " $other";
        }
        $state->list("List of civs starting with tech \"$tech_name\":\n", @civs);
        return 1;
    }
    
    my @techs = map { _format_tech_name($_) } (sort keys %{ $state->{'data'}{'techs'} });
    $state->list( @techs );
    return 1;
}

sub _find_other_techs_name {
    my ($state, $first_tech, $civ_name) = @_;
    
    my @techs = @{ $state->{'data'}{'civs'}{$civ_name}{'_Tech'} };
    @techs = grep { $_ ne $first_tech } @techs;
    return '' if @techs == 0;
    return '(' . join(',', map { _format_tech_name($_) } @techs) . ')';
}

my $list_leaders_help_text = qq[
    List all valid leader names. If '--trait' is specified, only leaders having that trait will be listed.
];
sub list_leaders {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'help_text' => $list_leaders_help_text,
        'optional' => {
            'trait' => ''
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $trait_name_exact = $pparams->get_named("trait");
    my $trait_name = $pparams->get_named("trait");
    $trait_name =~ s/^TRAIT_//;
    $trait_name = ucfirst(lc($trait_name));
    
    my $trait_name_proper;
    if (length($trait_name) == 3) {
        foreach my $trait (keys %{ $state->{'data'}{'traits'} }) {
            if ($trait =~ /TRAIT_$trait_name/i) {
                $trait_name_proper = $trait;
                
            }
        }
    }
    else {
        $trait_name_proper = 'TRAIT_' . uc($trait_name);
        $trait_name = _format_trait($trait_name);
    }
    
    if ($trait_name_exact ne '') {
        if (! exists $state->{'data'}{'traits'}{$trait_name_proper}) {
            $state->report_error("Unknown trait name: \'$trait_name_exact\'.");
            return -1;
        }
        
        my @leaders;
        foreach my $leader_name (sort @{ $state->{'data'}{'traits'}{$trait_name_proper} }) {
            push @leaders, _format_leader($state, $leader_name);
        }
        
        $state->list("List of leaders with trait \"$trait_name\":\n", @leaders );
        return 1;
    }
    
    my @leaders;
    foreach my $leader (sort keys %{ $state->{'data'}{'leaders'}}) {
        push @leaders, _format_leader($state, $leader);
    }

    $state->list( @leaders );
    return 1;
}

my $list_traits_help_text = qq[
    List all valid traits. If '--trait' is specified, only leaders for that trait will be listed.
];
sub list_traits {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'help_text' => $list_traits_help_text,
        'optional' => {
            'trait' => ''
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $trait_name_exact = $pparams->get_named("trait");
    my $trait_name = $pparams->get_named("trait");
    $trait_name =~ s/^TRAIT_//;
    $trait_name = ucfirst(lc($trait_name));
    
    my $trait_name_proper;
    if (length($trait_name) == 3) {
        foreach my $trait (keys %{ $state->{'data'}{'traits'} }) {
            if ($trait =~ /TRAIT_$trait_name/i) {
                $trait_name_proper = $trait;
                
            }
        }
    }
    else {
        $trait_name_proper = 'TRAIT_' . uc($trait_name);
        $trait_name = _format_trait($trait_name);
    }
    
    if ($trait_name_exact ne '') {
        if (! exists $state->{'data'}{'traits'}{$trait_name_proper}) {
            $state->report_error("Unknown trait name: \'$trait_name_exact\'.");
            return -1;
        }
    
        my $data = $state->{'data'}{'traits'}{$trait_name_proper};
        my @leaders;
        foreach my $leader (sort @$data) {
            push @leaders, _format_leader($state, $leader);
        }

        $state->list( "List of leaders with trait \"$trait_name\":\n", @leaders );
        return 1;
    }
    
    my @traits = sort keys %{ $state->{'data'}{'traits'} };
    @traits = map { _format_trait($_) } @traits;
    $state->list( @traits );
    return 1;
}

my $show_difficulty_help_text = qq[
    Shows the current difficulty level, which all players in all layers in all groups will share.
];
sub show_difficulty {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'help_text' => $show_difficulty_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my $diff = $main::config{'difficulty'};
    $diff =~ s/^HANDICAP_//;
    $state->list ( ucfirst(lc($diff)) );
    return 1;
}

my $find_starts_help_text = qq[
    Finds starts (settlers) in a group and reports their locations.
];

sub find_starts {
    my ($state, @params) = @_;
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group to find settlers in'],
        'help_text' => $find_starts_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($group) = $pparams->get_required();
    my $all_starts = $group->find_starts();
    
    my @sorted_starts;
    foreach my $start (@$all_starts) {
        push @sorted_starts, map {[$start->[0], @$_]} @{ $start->[1] };
    }
    @sorted_starts = sort { $b->[3] <=> $a->[3] } @sorted_starts;
    
    if (@sorted_starts == 0) {
        $state->list('No starts found.');
    }
    else {
        my %dups; my $any_dup = 0;
        foreach my $start (@sorted_starts) {
            $dups{ $start->[3] } = 0 unless exists $dups{ $start->[3] };
            $dups{ $start->[3] } ++;
            $any_dup = 1 if $dups{ $start->[3] } > 1;
        }
        
        my @descriptions;
        foreach my $start (@sorted_starts) {
            my $full_layer_name = '$' . $group->get_name() . '.' . $start->[0];
            my $layer = $state->get_variable($full_layer_name, 'layer');
            my $civ = '';
            
            if (! $any_dup) {
                my ($player, $team) = $layer->get_player_data($start->[3]);
                my $leader = _format_leader($state, $player->get('LeaderType'));
                $leader =~ s/ \(\w+\/\w+\)//;
                $civ = sprintf ", %s of %s", $leader, _format_civ_name($player->get('CivType'));
            }
            
            my $desc = sprintf "player %s%s; layer '%s' at %d,%d", $start->[3], $civ, $start->[0], $start->[1], $start->[2];
            push @descriptions, $desc;
        }
        
        if ($any_dup) {
            push @descriptions, "\n  Duplicates detected; starts need to be normalized by 'normalize_starts'";
            push @descriptions, "or 'flatten_group' for player data to be extracted.";
        }
        $state->list( @descriptions );
    }
    
    return 1;
}

sub _format_civ_name {
    my ($name) = @_;
    $name =~ s/^CIVILIZATION_//i;
    return join ' ', (map { ucfirst(lc($_)) } (split /_|\s+/, $name));
}

sub _format_leader {
    my ($state, $leader_name) = @_;
    
    my @traits = @{ $state->{'data'}{'leaders'}{$leader_name}{'Traits'} };
    @traits = sort map { _format_trait($_) } @traits;
    my $trait_str = '(' . join('/', @traits) . ')';
    
    $leader_name =~ s/^LEADER_//i;
    $leader_name = join(' ', (map { ucfirst(lc($_)) } (split /_|\s+/, $leader_name)));
    
    return "$leader_name $trait_str";
}

sub _format_tech_name {
    my ($name) = @_;
    $name =~ s/^TECH_//i;
    
    return join ' ', (map { ucfirst(lc($_)) } (split /_|\s+/, $name));
}

sub _format_color_name {
    my ($name) = @_;
    $name =~ s/^PLAYERCOLOR_//i;
    return join ' ', (map { ucfirst(lc($_)) } (split /_|\s+/, $name));
}

sub _format_trait {
    my ($name) = @_;
    $name =~ s/^TRAIT_//i;
    $name = substr(ucfirst(lc($name)), 0, 3);
    return $name
}

1;