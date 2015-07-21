#!perl

use strict;
use warnings;

use lib 'lib';
use XML::Simple qw(:strict);
use Config::General;

# THIS SHOULD BE CALLED FROM MAIN "civ4 mapcad" directory"
our %config = Config::General->new('def/config.cfg')->getall();

my $state = {};

my $civdata = XMLin($main::config{'civ4_info_path'}, KeyAttr => {  }, ForceArray => [ 'CivilizationInfo', 'Cities', 'Building', 'Unit', 'FreeTech', 'FreeBuildingClass', 'FreeUnitClass', 'CivicType', 'Leader' ]);

my $flagdata = XMLin($main::config{'civ4_artdefines_path'}, KeyAttr => {  }, ForceArray => [ 'CivilizationArtInfo' ]);
my $leaderdata = XMLin($main::config{'civ4_leaders_path'}, KeyAttr => {  }, ForceArray => [ 'LeaderHeadInfo', 'DiploMusicPeaceEra', 'DiploMusicWarEra', 'MemoryDecay', 'ContactDelay', 'ContactRand', 'Flavor', 'Trait', 'MemoryAttitudePercent', 'NoWarAttitudeProb',  ]);

my %flags;
foreach my $flag (@{ $flagdata->{'CivilizationArtInfos'}{'CivilizationArtInfo'} }) {
    $flags{ $flag->{'Type'} } = {
        'FlagDecal' => $flag->{'Path'},
        'WhiteFlag' => $flag->{'bWhiteFlag'}
    }
}

my %leaders;
foreach my $leaderhead (@{ $leaderdata->{'LeaderHeadInfos'}{'LeaderHeadInfo'} }) {
    my $type = $leaderhead->{'Type'};
    $leaders{$type} = {
        'Traits' => [],
        'Name' => $leaderhead->{ 'Description' }
    };
    
    foreach my $trait (@{ $leaderhead->{'Traits'}{'Trait'} }) {
        push @{ $leaders{$type}{'Traits'} }, $trait->{'TraitType'};
    }
}

my %civs;
my %colors;
my %techs;

foreach my $civ (@{ $civdata->{'CivilizationInfos'}{'CivilizationInfo'} }) {
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
        'Handicap' => 'HANDICAP_MONARCH',
        '_Tech' => [],
        '_LeaderType' => [],
        '_Civics' => [
            'CivicOption=CIVICOPTION_GOVERNMENT, Civic=CIVIC_DESPOTISM',
            'CivicOption=CivicOption=CIVICOPTION_LEGAL, Civic=CIVICOPTION_LABOR',
            'CivicOption=CivicOption=CIVICOPTION_LABOR, Civic=CIVICOPTION_ECONOMY',
            'CivicOption=CivicOption=CIVICOPTION_ECONOMY, Civic=CIVIC_DECENTRALIZATION',
            'CivicOption=CivicOption=CIVICOPTION_RELIGION, Civic=CIVIC_PAGANISM',
        ]
    );
    
    $colors{ $civ->{'DefaultPlayerColor'} } = 1;
    
    foreach my $tech (@{ $civ->{'FreeTechs'}{'FreeTech'} }) {
        my $techtype = $tech->{'TechType'};
        $techs{$techtype} = [] unless exists $techs{$techtype};
        push @{ $techs{$techtype} }, $type;
        push @{ $info{'_Tech'} }, $techtype;
    }
    
    foreach my $leader (@{ $civ->{'Leaders'}{'Leader'} }) {
        push @{ $info{'_Leaders'} }, $leader->{'LeaderName'};
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
    'civs' => \%civs,
    'techs' => \%techs
};
