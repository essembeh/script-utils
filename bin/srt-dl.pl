#!/usr/bin/perl 
##
## srt-dl a tool to download srt.
##
##
## Dependencies (for Debian GNU/Linux): 
##   apt-get install libwww-perl libtext-levenshtein-perl libarchive-any-perl
##
## Using cpan:
##   install Text::Levenshtein 
##
package org::essembeh::script;

use strict;
use LWP::Simple;
use File::Basename;
use Archive::Extract;
use Getopt::Long;
use Text::Levenshtein qw/distance/;
use File::Temp qw/tempfile tempdir/;
use File::Copy;


our ($VERBOSE, $STEU_PREFIX, $LEVENSHSTEIN_OPTIM);

$STEU_PREFIX = "http://www.sous-titres.eu/series/";
$LEVENSHSTEIN_OPTIM = ".fr.vf";


##
## Log message if verbose mode is set
##
sub printMessage {
	my $type = $_[0];
	unless ($type) {
		print "\n";
	} elsif ($VERBOSE || $type ne "debug") {
		for (my $i = 1; $i < @_; $i++) {
			$type = "[".$type."]";
			printf("%10s %s\n", $type, $_[$i]);
		}
	}
}

##
##
##
sub findSrtInFolder {
	my $folder = $_[0];
	opendir (my $dh, $folder);
	my @content;
	foreach my $file (readdir $dh) {
		unless ($file =~ /^\.{1,2}$/) {
			$file = $folder."/".$file;
			if (-d $file) {
				push (@content, &findSrtInFolder($file));
			} elsif (-f $file && $file =~ /\.srt$/) {
				push (@content, $file);
			}
		}
	}
	&printMessage("debug", "Found ".@content." file(s) in folder: ".$folder);
	@content;
}

##
## Sort of basename
##
sub myBasename {
	my $filename = substr($_[0], rindex($_[0], "/") + 1); 
	$filename;
}

##
## Uniform string for distance computation
##
sub unifString {
	my $str = $_[0];
	$str =~ tr/[A-Z]/[a-z]/;
	$str =~ s/[^A-Za-z0-9]/./g;
	$str =~ s/[sS]0*([0-9]+)[eE]([0-9]+)/$1$2/;
	$str =~ s/([0-9]+)x([0-9]+)/$1$2/;
	my @words = sort(split(/\./, $str));
	$str = "";
	foreach my $word (@words) {
		$str = $str.$word.".";
	}
	$str;
}

##
## Comput string distance
##
sub myDistance {
	my $a = &unifString($_[0]);
	my $b = &unifString($_[1]);
	my $dist = distance($a, $b);
	$dist = abs($dist);
	&printMessage("debug", "Distance: ".$dist.", ".$a." / ".$b);
	$dist;
}

##
## Get the serie URL on STEU
##
sub getSTEUSerieHomepage {
	my $serieName = $_[0];
	$serieName =~ tr/[A-Z]/[a-z]_/; 
	$serieName =~ s/[\. ]/_/g;
	my $url = $STEU_PREFIX.$serieName.".html";
	&printMessage("debug", "Serie Homepage: ".$url);
	$url;
}

##
## Get Episode number
##
sub getInformationFromEpisodeName {
	my $file = $_[0];
	my %infos;
	if ($file =~ /(.*)[ .][sS]0*(\d+)[eE](\d+).*/) {
		$infos{serie} = $1;
		$infos{season} = $2;
		$infos{episode} = $3;
		&printMessage("debug", "Serie name: ".$infos{serie}.", season: ".$infos{season}.", ep: ".$infos{episode});
		%infos;
	}
}

##
## Get all zip corresponding the
##
sub getAllPackForSerie {
	my %fileInfos=@_;
	my $serieHomepage = &getSTEUSerieHomepage($fileInfos{serie});
	my %listOfPacks;
	my $html = get($serieHomepage);
	if ($html) {
		my @html = split("\n", $html);
		foreach my $line (@html) {
			if ($line =~ /href=.(.*\.zip)/) {
				my $value=$STEU_PREFIX.$1;
				my $key=&myBasename($value);
				&printMessage("debug", "Found pack: ".$key);
				$listOfPacks{$key} = $value;
			}
		}
		%listOfPacks;
	}
}

##
##
##
sub autoChoosePack {
	my ($season, $episode, %listOfPacks) = @_;
	my $pattern = sprintf("%dx%02d", $season, $episode);
	my $selectedPack; 
	while ( my ($key, $value) = each(%listOfPacks) ) {
		if ($key =~ /$pattern/) {
			&printMessage("debug", "Auto choose pack: ".$key);
			$selectedPack = $value;
			last
		}
	}
	$selectedPack;
}

##
##
##
sub getAllSubtitlesForPack {
	my $packUrl = $_[0];
	# Download the pack
	my $tmpFile = &downloadTmpFile($packUrl);
	# Unzip the pack
	my $zipObject = Archive::Extract->new(archive => $tmpFile, type => 'zip') or die "Error openning zip:".$tmpFile;
	my $tmpDir = tempdir();
	&printMessage("debug", "Extract zip: ".$tmpFile.", to folder:".$tmpDir);
	$zipObject->extract(to => $tmpDir);
	my @content = &findSrtInFolder($tmpDir);
	my %content;
	foreach my $srtFile (@content) {
		my $basename = &myBasename($srtFile);
		$content{$basename} = $srtFile;
	}
	%content;
}

##
##
##
sub autoChooseSubtitle {
	my $reference = shift;
	my %listOfSubtitles = @_;
	my $bestDistance = -1;
	my $bestKey;
	my $bestValue;
	while ( my ($key, $value) = each(%listOfSubtitles) ) {
		my $distance = &myDistance($reference.$LEVENSHSTEIN_OPTIM, $key);
		if ($bestDistance < 0 || $distance < $bestDistance) {
			$bestKey = $key;
			$bestValue = $value;
			$bestDistance = $distance;
		}
	}
	&printMessage("debug", "Auto choose srt: ".$bestKey);
	$bestValue;
}

##
##
##
sub userSelection {
	my %hash = @_;
	my @keys = sort(keys %hash);
	my $max = @keys;
	for (my $i = 0; $i < $max; $i++) {
		my $key = @keys[$i];
		&printMessage("question", "[".$i."] ".$key);
	}
	my $item;
	do {
		&printMessage("question", "Select a file: [0-".($max-1)."]?");
		chop($item = <STDIN>);
	}until ($item =~ /^\d+$/ && $item>=0 && $item < $max);
	my $selection = $hash{$keys[$item]};
	&printMessage("debug", "Selection: ".$selection);
	$selection;
}

##
##
##
sub downloadTmpFile {
	my $url = $_[0];
	my $document = get($url);
	if ($document) {
		my ($tmpFile, $tmpPath) = tempfile();
		$tmpFile->write($document);
		$tmpFile->close();
		&printMessage("debug", "File successfully downloaded: ".$url." --> ".$tmpPath);
		$tmpPath;
	} else {
		&printMessage("debug", "Error getting url: ".$url);
	}
}
	
##
##
##
sub computeTargetSrtFile {
	my $file = $_[0];
	$file =~ s/[^\.]*$//;
	$file =~ s/$/srt/;
	&printMessage("debug", "Target srt: ".$file);
	$file;
}

##
## Removes tags from srt
##
sub removeTagFromSubtitle {
	my $srtPath = $_[0];
	my ($tmpFile, $tmpPath) = tempfile();
	&printMessage("debug", "Backup srt file: ".$tmpPath);
	copy ($srtPath, $tmpPath);
	my $srtFile = FileHandle->new($srtPath, "w");
	my $tmpFile = FileHandle->new($tmpPath, "r");
	my $nbTags = 0;
	while (my $line = <$tmpFile>) {
		$line =~ s/<[^>]*>//g and $nbTags++;
		$line =~ s/\{[^\}].*\}//g and $nbTags++;
		$srtFile->write($line);
	}
	&printMessage("info", "Clean subtitle: ".$nbTags." tag(s) removed");
	$tmpFile->close();
	$srtFile->close();
}

##
##
##
sub copySubtitle () {
	my $source = $_[0];
	my $destination = $_[1];
	&printMessage("info", "Copying: ".&myBasename($source));
	copy($source, $destination);
}
	

##
##
##
sub displayHelp {
    print"\
NAME
    srt-dl - Sub title downloader version 1.1

USAGE
    srt-dl [OPTIONS] <EPISODE> <EPISODE> ...

OPTIONS
    --help
        Diplay this message.

    -f, --force
    --noforce (default) 
        To force srt download even if srt file is already present.
        By default if a srt file is present, nohting will be done.

    -v, --verbose 
    --noverbose (default)
        To display debug informations.

    --autopack (default)
    --noautopack 
        Automatically try to fetch the pack of subtitles corresponding to the 
        given episode from its number.
        If no result, try --allzip to show all available srt zip files.
    
    --autosrt (default)
    --noautosrt
        Automatically try to choose the srt that better matches the episode 
        name using the Levenshtein distance.

    -c, --clean 
    --noclean (default)
        Clean tags if the srt files has some.

EXAMPLES
    srt-dl --force --verbose --clean My.Serie.S02E04.mkv
        Automatically try to download subtitles for the episode 2x04.
        Then choose the better one. 
        Finally, the srt file will get its tags removed.
        Note: if a My.Serie.S02E04.srt already exists, it will be overwritten.

COPYRIGHT
    Copyright 2011 essembeh.org
    Licence GPLv2.
";
}

##
## Main 
##
my ($optionAutopack, $optionAutosrt, $optionForce, $optionClean, $optionHelp) = (1, 1, 0, 0, 0);
unless (GetOptions(	"help"       => \$optionHelp, 
					"v|verbose!" => \$VERBOSE, 
					"f|force!"   => \$optionForce, 
					"autosrt!"   => \$optionAutosrt, 
					"autopack!"  => \$optionAutopack, 
					"c|clean!"   => \$optionClean)) {
	displayHelp;
	exit 1;
}

if ($optionHelp) {
	displayHelp;
	exit 0;
}

my $count = 0;
foreach my $file (@ARGV) {
	&printMessage() if ($count ++);
	&printMessage("info", "Fetching srt for episode: ".$file);
	
	## Step 0: Compute srt target file
	my $targetSrtFile=&computeTargetSrtFile($file);
	if (-f $targetSrtFile) {
		if ($optionForce) {
			&printMessage("info", "Srt already exists, will be overwritten");
		} else {
			&printMessage("error", "The srt file already exists (use --force to overwrite)");
			next;
		}
	}

	## Step 1: File information
	my %fileInfos = &getInformationFromEpisodeName($file);
	unless (%fileInfos) {
		&printMessage("error", "Error getting informations from filename: ".$file);
		next;
	}
	
	## Step 2a: Get all zip
	my %listOfPacks = &getAllPackForSerie(%fileInfos);
	unless (%listOfPacks) {
		&printMessage ("error", "Cannot find any pack for the serie");
		next;
	}

	## Step 2b: Choose a pack
	my $selectedPackUrl;
	if ($optionAutopack) {
		$selectedPackUrl = &autoChoosePack ($fileInfos{season}, $fileInfos{episode}, %listOfPacks);
	} else {
		$selectedPackUrl = &userSelection (%listOfPacks);
	}
	unless ($selectedPackUrl) {
		&printMessage("error", "Invalid pack");
		next;
	}

	## Step 3a: Get srt list
	my %listOfSubtitles = &getAllSubtitlesForPack($selectedPackUrl);
	unless (%listOfSubtitles) {
		&printMessage("error", "No srt found selected pack");
		next;
	}
		
	## Step 3b: Choose a srt
	my $selectedSubtitleUrl;
	if ($optionAutosrt) {
		$selectedSubtitleUrl = &autoChooseSubtitle ($targetSrtFile, %listOfSubtitles);
	} else {
		$selectedSubtitleUrl = &userSelection (%listOfSubtitles);
	}
	unless ($selectedSubtitleUrl) {
		&printMessage("error", "Invalid subtitle");
		next;
	}

	## Step 4: Copy the srt
	&copySubtitle($selectedSubtitleUrl, $targetSrtFile);

	## Step 5: Clean the srt
	if ($optionClean) {
		&removeTagFromSubtitle($targetSrtFile);
	}
}

