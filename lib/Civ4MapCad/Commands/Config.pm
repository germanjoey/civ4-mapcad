package Civ4MapCad::Commands::Config;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(set_output_dir list_mods set_mod write_log history set_player_data load_xml_data set_difficulty ls set_settings add_sign);

use Config::General;
use XML::Simple qw(:strict);

use Civ4MapCad::ParamParser;

my $ls_help_text = qq[
    List directory. Like the unix command, except there's no corresponding 'cd'. Sorry.
];
sub ls {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['str'],
        'required_descriptions' => ['directory path'],
        'help_text' => $ls_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($directory_path) = $pparams->get_required();
    $directory_path =~ s/\*+$//;
    $directory_path =~ s/\/+$//;
    $directory_path =~ s/^\s+//;
    $directory_path =~ s/\s+$//;
    
    my @dir = map { "  $_" } glob("$directory_path/*");
    $state->list( "Contents of '$directory_path':\n", @dir );
    return 1;
}

my $set_output_dir_help_text = qq[
    Sets the default output directory for other commands, e.g. export_sims.
];
sub set_output_dir {
    my ($state, @params) = @_;

    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['str'],
        'required_descriptions' => ['directory path'],
        'help_text' => $set_output_dir_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($directory) = $pparams->get_required();
    
    $state->{'config'}{'output_dir'} = $directory;
    if (! -e $directory) {
        mkdir($directory);
    }
    
    return 1;
}

my $list_mods_help_text = qq[
    Lists all available mods that can be set via the 'set_mod' command.
];
sub list_mods {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'help_text' => $list_mods_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my @mods = map { /mods\/(.+)$/ } grep { -d $_ } glob("mods/*");
    
    $state->list( qq[The current mod is: "$state->{'mod'}"\n], 'Available Mods: ', map { qq[  "$_"] } @mods );
    return 1;
}

my $set_mod_help_text = qq[
    Sets the current mod, and thus a.) reloads all xml data, b.) clears and reloads all terrain definitions, and c.) set the maximum number of players recognized by the savefile. All existing groups in memory will be converted to assume this mod's format and any newly created/imported groups will be automatically converted as well, although keep in mind converting a group from a high number of players (e.g. an RtR mod save) to a low number (e.g. if the current mod is "none") and then back again (e.g. using set_mod "RtR 2.0.7.4" after the save is already imported) will end up clearing those players that couldn't fit in the low number.
];
sub set_mod {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['str'],
        'required_descriptions' => ['mod name'],
        'help_text' => $set_mod_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($mod) = $pparams->get_required();
    
    unless ((-e "mods/$mod") and (-e "mods/$mod/$mod.cfg") and (-e "mods/$mod/$mod.init.civ4mc")) {
        $state->report_error("either mod directory 'mods/$mod' does not exist or its definition files, 'mods/$mod/$mod.cfg' and 'mods/$mod/$mod.init.civ4mc', cannot be loaded.");
        return -1;
    }
    
    if ((! exists $state->{'config'}{'civ4_exe'}) or (! -e $state->{'config'}{'civ4_exe'})) {
        $state->report_error("The civ4 .exe path was not found or does not exist! Please set it correctly in 'def/config.cfg'.");
        exit(-1);
    }
    
    $state->{'config'}{'output_dir'} = '.' unless exists $state->{'config'}{'output_dir'};
    
    if (! -e $state->{'config'}{'output_dir'}) {
        mkdir($state->{'config'}{'output_dir'});
    }
    
    if (! exists $state->{'config'}{'civ4_path'}) {
        $state->{'config'}{'civ4_path'} = "$state->{'config'}{'civ4_exe'}";
        $state->{'config'}{'civ4_path'} =~ s/Civ4BeyondSword\w*.exe$//;
        $state->{'config'}{'civ4_path'} =~ s/\/+$//;
        $state->{'config'}{'civ4_path'} =~ s/\\+$//;
        $state->{'config'}{'civ4_path'} =~ s/\\+/\//g;
    }
    
    our %config = Config::General->new("mods/$mod/$mod.cfg")->getall();
    foreach my $item (keys %config) {
        if ($config{$item} =~ /\$civ4_path/) {
            $config{$item} =~ s/\\+/\//g;
            $config{$item} =~ s/\$civ4_path/$state->{'config'}{'civ4_path'}/;
            if (! -e $config{$item}) {
                $state->report_error("Can't find XML file: \"$config{$item}\".");
                exit(-1);
            }
        }
    
        $state->{'config'}{$item} = $config{$item};
    }
    
    my $max = $state->{'config'}{'max_players'};
    my @groups = sort keys %{ $state->{'group'} };
    if (@groups > 0) {
        my @modified;
        foreach my $group_name (@groups) {
            my $group = $state->{'group'}{$group_name};
            push @modified, "* Setting $group_name to $max players.";
            
            my $total = 0;
            foreach my $layer ($group->get_layers()) {
                $total += $layer->set_max_num_players($max);
            }
            shift @modified unless $total > 0;
            
            $state->set_variable($group_name, 'group', $group);
        }
        
        $state->list( @modified ) if @modified > 0;
    }
    
    delete $state->{'data'};
    delete $state->{'terrain'};
    
    $state->{'mod'} = $mod;
    
    $state->process_command(qq[run_script "mods/$mod/$mod.init.civ4mc"]);
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
        },
        'optional_descriptions' => {
            'filename' => 'Specify a different filename.'
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
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
    return 1 if $pparams->done;
    
    my @log;
    my $i = 0;
    foreach my $cmd ($state->get_log()) {
        $i ++;
        push @log, "  $i: $cmd";
    }
    
    $state->list( @log );
    return 1;
}

my $load_xml_data_help_text = qq[
    Loads leader, civ, color, and tech data from the xml files. Set paths in def/config.xml to change the locations of the xml files read,
    and use the 'list_civs', 'list_leaders', 'list_colors', 'list_techs', 'set_player_data' commands to browse/manipulate the read data.
];
sub load_xml_data {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'help_text' => $load_xml_data_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;

    $state->buffer_bar();
    local $| = 1;
    print "\n  Loading XML data...";
    local $| = 0;
    
    my $civdata = XMLin($state->{'config'}{'civ4_info_path'}, KeyAttr => {  }, ForceArray => [ 'CivilizationInfo', 'Cities', 'Building', 'Unit', 'FreeTech', 'FreeBuildingClass', 'FreeUnitClass', 'CivicType', 'Leader' ]);
    my $flagdata = XMLin($state->{'config'}{'civ4_artdefines_path'}, KeyAttr => {  }, ForceArray => [ 'CivilizationArtInfo' ]);
    my $leaderdata = XMLin($state->{'config'}{'civ4_leaders_path'}, KeyAttr => {  }, ForceArray => [ 'LeaderHeadInfo', 'DiploMusicPeaceEra', 'DiploMusicWarEra', 'MemoryDecay', 'ContactDelay', 'ContactRand', 'Flavor', 'Trait', 'MemoryAttitudePercent', 'NoWarAttitudeProb'  ]);
    my $civicdata = XMLin($state->{'config'}{'civ4_civics_path'}, KeyAttr => {  }, ForceArray => [ 'CivicInfo' ]);
    my $colordata = XMLin($state->{'config'}{'civ4_colors_path'}, KeyAttr => {  }, ForceArray => [ 'ColorVal' ]);
    
    my %flags;
    foreach my $flag (@{ $flagdata->{'CivilizationArtInfos'}{'CivilizationArtInfo'} }) {
        $flags{ $flag->{'Type'} } = {
            'FlagType' => $flag->{'Type'},
            'FlagDecal' => $flag->{'Path'},
            'WhiteFlag' => $flag->{'bWhiteFlag'},
        }
    }
    
    my %civics;
    foreach my $civic (@{ $civicdata->{'CivicInfos'}{'CivicInfo'} }) {
        my $option_type = $civic->{'CivicOptionType'};
        $civics{$option_type} = {} unless exists $civics{$option_type};
        $civics{$option_type}{ $civic->{'Type'} } = 1;
    }
    
    my %leaders;
    my %traits;
    foreach my $leaderhead (@{ $leaderdata->{'LeaderHeadInfos'}{'LeaderHeadInfo'} }) {
        my $type = $leaderhead->{'Type'};
        $leaders{$type} = {
            'Traits' => [],
            'LeaderType' => $type,
            'Name' => $leaderhead->{ 'Description' }
        };
        
        foreach my $trait (@{ $leaderhead->{'Traits'}{'Trait'} }) {
            my $trait_type = $trait->{'TraitType'};
            push @{ $leaders{$type}{'Traits'} }, $trait_type;
            
            $traits{$trait_type} = [] unless exists $traits{$trait_type};
            push @{ $traits{$trait_type} }, $type;
        }
    }
    
    my %colorcodes;
    foreach my $colorcode (@{ $colordata->{'ColorVals'}{'ColorVal'} }) {
        my $type = $colorcode->{'Type'};
        
        my $red = $colorcode->{'fRed'};
        my $green = $colorcode->{'fGreen'};
        my $blue = $colorcode->{'fBlue'};
        my $alpha = $colorcode->{'fAlpha'};
        my $hex = sprintf "%02x%02x%02x", int(255*$red), int(255*$green), int(255*$blue);
        
        $colorcodes{$type} = {
            'opacity' => $alpha,
            'rgba' => [$red, $green, $blue, $alpha],
            'hex' => '#' .$hex
        }
    }

    my %civs;
    my %colors;
    my %techs;
    foreach my $civ (@{ $civdata->{'CivilizationInfos'}{'CivilizationInfo'} }) {
        next if ($civ->{'bPlayable'} == 0);
        my $type = $civ->{'Type'};
        
        my %info = (
            'CivType' => $type,
            'CivDesc' => $civ->{'Description'},
            'CivShortDesc' => $civ->{'ShortDescription'},
            'CivAdjective' => $civ->{'Adjective'},
            'Color' => $civ->{'DefaultPlayerColor'},
            'ArtStyle' => $civ->{'ArtStyleType'},
            'PlayableCiv' => 1,
            'MinorNationStatus' => 0,
            'StartingX' => 0,
            'StartingY' => 0,
            'StateReligion' => '',
            'RandomStartLocation' => 'false',
            'Handicap' => $state->{'config'}{'difficulty'},
            '_Tech' => [],
            '_LeaderType' => [],
            '_Civics' => []
        );
        
        $colors{ $civ->{'DefaultPlayerColor'} } = [] unless exists $colors{ $civ->{'DefaultPlayerColor'} };
        push @{ $colors{ $civ->{'DefaultPlayerColor'} } }, $type;
        
        foreach my $civic (@{ $civ->{'InitialCivics'}{'CivicType'} }) {
            my $option_type;
            foreach my $option (keys %civics) {
                if (exists $civics{$option}{$civic}) {
                    $option_type = $option;
                    last;
                }
            }
            
            push @{ $info{'_Civics'} }, "CivicOption=$option_type, Civic=$civic"
        }
        
        foreach my $tech (@{ $civ->{'FreeTechs'}{'FreeTech'} }) {
            my $techtype = $tech->{'TechType'};
            $techs{$techtype} = [] unless exists $techs{$techtype};
            push @{ $techs{$techtype} }, $type;
            push @{ $info{'_Tech'} }, $techtype;
        }
        
        foreach my $leader (@{ $civ->{'Leaders'}{'Leader'} }) {
            my $leader_text = $leaders{ $leader->{'LeaderName'} }{'Name'};
            push @{ $info{'_LeaderType'} }, [$leader->{'LeaderName'}, $leader_text];
            $leaders{ $leader->{'LeaderName'} }{'DefaultCiv'} = $type;
        }
        
        my $art_type = $civ->{'ArtDefineTag'};
        $info{'FlagDecal'} =  $flags{$art_type}{'FlagDecal'};
        $info{'WhiteFlag'} = $flags{$art_type}{'WhiteFlag'};
        
        $civs{$type} = \%info;
    }

    $state->{'data'} = {
        'leaders' => \%leaders,
        'colors' => \%colors,
        'colorcodes' => \%colorcodes,
        'civs' => \%civs,
        'techs' => \%techs,
        'traits' => \%traits,
        'civics' => \%civics
    };
    
    print "...done.\n\n";
    $state->register_print();
    
    return 1;
}

# note: the difficulty list gets outputted inside the command!
my $set_difficulty_help_text = qq[
    Sets difficulty level for all players of all civs. Acceptable values are:
];
sub set_difficulty {
    my ($state, @params) = @_;
    
    my @difficulty_list = (
        'HANDICAP_SETTLER',
        'HANDICAP_CHIEFTAIN',
        'HANDICAP_WARLORD',
        'HANDICAP_NOBLE',
        'HANDICAP_PRINCE',
        'HANDICAP_MONARCH',
        'HANDICAP_EMPEROR',
        'HANDICAP_IMMORTAL',
        'HANDICAP_DEITY'
    );
    
    my $dlist = join "\", \"", @difficulty_list;
    $dlist =~ s/, ("\w+)$/, and $1/;
    
    chomp($set_difficulty_help_text);
    $set_difficulty_help_text .= " \"$dlist\"\n";
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['str'],
        'required_descriptions' => ['difficulty name'],
        'help_text' => $set_difficulty_help_text
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($diff_name) = $pparams->get_required();
    my %diff;
    
    @diff{@difficulty_list} = (1) x @difficulty_list;
    
    if (! exists $diff{$diff_name}) {
        $state->report_error("Unknown difficulty name '$diff_name'. Allowed values are: '$dlist'.");
        return -1;
    }

    # loop through all groups in memory and set the difficulty level of all players in each one
    my @groups = sort keys %{ $state->{'group'} };
    if (@groups > 0) {
        my @modified;
        foreach my $group_name (@groups) {
            my $group = $state->{'group'}{$group_name};
            push @modified, "* Setting all players in $group_name to $diff_name handicap.";
            
            my $total = 0;
            foreach my $layer ($group->get_layers()) {
                $total += $layer->set_difficulty($diff_name);
            }
            shift @modified unless $total > 0;
        }
        
        $state->list( @modified ) if @modified > 0;
    }
    
    $state->{'config'}{'difficulty'} = $diff_name;
    return 1;
}

my $set_player_data_help_text = qq[
    Sets a particular player's data. You can pick and choose from any or all four options (civ/leader/color/player_name), although a map will not be playable unless civ is set either with this command or from importing an already-built map. 
];
sub set_player_data {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group', 'int'],
        'required_descriptions' => ['group with player to set', 'the player number whose data to set'],
        'help_text' => $set_player_data_help_text,
        'optional' => {
            'civ' => '',
            'color' => '',
            'leader' => '',
            'player_name' => ''
        },
        'optional_descriptions' => {
            'civ' => "Setting set (see 'list_civs' for possible values), will load all values for that civ, including a default leader, leader name, color, and techs.",
            'leader' => "If set (see 'list_leaders' for possible values), will override the default leader value from '--civ' If '--leader' is set but '--civ' is not, the matching restricted civ for that leader will be used.",
            'color' => "If set (see 'list_colors' for possible values), will override the default color value from '--civ'",
            'player_name' => "If set (see 'http://pr0nname.com/' for possible values), the default name of a player's leader is overwritten.",
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($group, $owner) = $pparams->get_required();
    
    my $civ = $pparams->get_named('civ');
    my $leader = $pparams->get_named('leader');
    my $player_name = $pparams->get_named('player_name');
    my $color = $pparams->get_named('color');
    
    my $player_name_proper = $pparams->get_named('playername');
    
    my $starts = $group->get_duplicate_owners();
    if (! exists $starts->{$owner}) {
        my $group_name = $group->get_name();
        $state->report_error("Civ owner '$owner' not found in group '$group_name'.");
    }
    
    if ($civ ne '') {
        my $civ_proper = uc $pparams->get_named('civ');
        $civ_proper =~ s/^CIVILIZATION_//i;
        $civ_proper =~ s/\s+/_/g;
        $civ_proper = 'CIVILIZATION_' . uc($civ_proper);
        
        if (! exists $state->{'data'}{'civs'}{$civ_proper}) {
            $state->report_error("civ '$civ' not found. Use 'list_civs' for valid civ names.");
        }
    
        $group->set_player_from_civdata($owner, $state->{'data'}{'civs'}{$civ_proper});
    }
    elsif ($leader ne '') {
        my $leader_proper = uc $pparams->get_named('leader');
        $leader_proper =~ s/^LEADER_//i;
        $leader_proper =~ s/\s+/_/g;
        $leader_proper = 'LEADER_' . uc($leader_proper);
        
        my @pos = sort keys %{$state->{'data'}{'leaders'}};
        
        if (! exists $state->{'data'}{'leaders'}{$leader_proper}) {
            $state->report_error("leader '$leader' not found. Use 'list_leaders' for valid leader names.");
        }
        
        my $default_civ_name = $state->{'data'}{'leaders'}{$leader_proper}{'DefaultCiv'};
        $group->set_player_from_civdata($owner, $state->{'data'}{'civs'}{$default_civ_name});
    }
    
    if ($leader ne '') {
        my $leader_proper = uc $pparams->get_named('leader');
        $leader_proper =~ s/^LEADER_//i;
        $leader_proper =~ s/\s+/_/g;
        $leader_proper = 'LEADER_' . uc($leader_proper);
        my @pos = sort keys %{$state->{'data'}{'leaders'}};
        
        if (! exists $state->{'data'}{'leaders'}{$leader_proper}) {
            $state->report_error("leader '$leader' not found. Use 'list_leaders' for valid leader names.");
        }
    
        $group->set_player_leader($owner, $state->{'data'}{'leaders'}{$leader_proper});
    }
    
    if ($color ne '') {
        my $color_proper = uc $pparams->get_named('color');
        $color_proper =~ s/^PLAYERCOLOR_//i;
        $color_proper =~ s/\s+/_/g;
        $color_proper = 'PLAYERCOLOR_' . uc($color_proper);
    
        if (! exists $state->{'data'}{'colors'}{$color_proper}) {
            $state->report_error("color '$color' not found. Use 'list_colors' for valid color names.");
        }
    
        $group->set_player_color($owner, $color_proper);
    }
    
    if ($player_name ne '') {
        $group->set_player_name($owner, $player_name);
    }
    
    return 1;
}

my $set_settings_help_text = qq[
    Sets settings data for a group and all of its layers. Options that aren't set will be ignored.
];
sub set_settings {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['group'],
        'required_descriptions' => ['group whose settings to set'],
        'help_text' => $set_settings_help_text,
        'optional' => {
            'size' => '',
            'speed' => '',
            'era' => '',
        },
        'optional_descriptions' => {
            'size' => "Sets the game's world size. Possible values are: duel, tiny, small, standard, large, and huge.",
            'speed' => "Sets the game speed. Possible values are: quick, normal, epic, and marathon.",
            'era' => "Sets the game's starting tech era. Possible values are: ancient, classical, medieval, renaissance, industrial, modern, and future.",
        }
    });
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($group) = $pparams->get_required();
    
    my $size = $pparams->get_named('size');
    my $speed = $pparams->get_named('speed');
    my $era = $pparams->get_named('era');
    
    $size =~ s/^WORLDSIZE_//i;
    if ($size ne '') {
        if ($size !~ /^(?:duel|tiny|small|standard|large|huge)$/i) {
            $state->report_error("Unknown size '$size'. Valid options are: duel, tiny, small, standard, large, and huge.");
            return -1;
        }
        $size = 'WORLDSIZE_' . uc($size);
    }
    
    if ($speed ne '') {
        $speed =~ s/^GAMESPEED_//i;
        if ($speed !~ /^(?:quick|normal|epic|marathon)$/) {
            $state->report_error("Unknown speed '$speed'. Valid options are: quick, normal, epic, and marathon.");
            return -1;
        }
        $speed = 'GAMESPEED_' . uc($speed);
    }
    
    $era =~ s/^ERA_//i;
    if ($era ne '') {
        if ($era !~ /^(?:ancient|classical|medieval|renaissance|industrial|modern|future)$/) {
            $state->report_error("Unknown era '$era'. Valid options are: ancient, classical, medieval, renaissance, industrial, modern, and future.");
            return -1;
        }
        $era = 'ERA_' . uc($era);
    }
    
    $group->set_size($size) if $size ne '';
    $group->set_speed($speed) if $speed ne '';
    $group->set_era($era) if $era ne '';
    
    return 1;
}

my $add_sign_help_text = qq[
    Adds a sign to a specified coordinate
];
sub add_sign {
    my ($state, @params) = @_;
    
    my $pparams = Civ4MapCad::ParamParser->new($state, \@params, {
        'required' => ['layer', 'int', 'int', 'str'],
        'required_descriptions' => ['layer in which to add the sign', 'x coordinate', 'y coordinate', 'caption'],
        'help_text' => $add_sign_help_text,
    });
    
    return -1 if $pparams->has_error;
    return 1 if $pparams->done;
    
    my ($layer, $x, $y, $caption) = $pparams->get_required();
    if (($x < 0) or ($x >= $layer->get_width()) or ($y < 0) or ($y < $layer->get_height())) {
        $state->report_error("Coordinate '$x,$y' is out of bounds!");
        return -1;
    }
    
    $layer->add_sign($x, $y, $caption);
    return 1;
}

1;