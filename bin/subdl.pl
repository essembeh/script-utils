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

use strict;

require LWP::Simple; 
require Text::Levenshtein; 
require File::Temp; 
require File::Copy; 
require Text::Iconv;
require Archive::Extract;
require Getopt::Long;


package Subdl::common;
use List::MoreUtils qw/uniq/;

##
## Log message if verbose mode is set
##
sub printMessage {
	my ($type) = @_;
	unless ($type) {
		print "\n";
	} elsif ($Subdl::main::VERBOSE || $type ne "debug") {
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
	my ($folder) = @_;
	opendir (my $dh, $folder);
	my @content;
	foreach my $file (readdir $dh) {
		unless ($file =~ /^\.{1,2}$/) {
			$file = $folder."/".$file;
			if (-d $file) {
				push (@content, findSrtInFolder($file));
			} elsif (-f $file && $file =~ /\.srt$/) {
				push (@content, $file);
			}
		}
	}
	printMessage("debug", "Found ".@content." file(s) in folder: ".$folder);
	return @content;
}

##
## Sort of basename
##
sub basename {
	my ($fullpath) = @_;
	my $filename = substr($fullpath, rindex($fullpath, "/") + 1); 
	return $filename;
}

##
## Uniform string for distance computation
##
sub unifString {
	my ($str) = @_;
	$str =~ tr/[A-Z]/[a-z]/;
	$str =~ s/[^A-Za-z0-9]/./g;
	$str =~ s/\.+/./g;
	$str =~ s/[sS]0*([0-9]+)[eE]([0-9]+)/$1$2/;
	$str =~ s/([0-9]+)x([0-9]+)/$1$2/;
	$str = join('.', sort(uniq(split(/\./, $str))));
	return $str;
}

##
## Comput string distance
##
sub distance {
	my ($a, $b) = @_;
	$a = unifString($a);
	$b = unifString($b);
	my $dist = Text::Levenshtein::distance($a, $b);
	$dist = abs($dist);
	return $dist;
}

##
## Get Episode number
##
sub getInformationFromEpisodeName {
	my ($file) = @_;
	$file = basename($file);
	my %infos;
	if ($file =~ /(.*)[ .][sS]0*(\d+)[eE](\d+).*/) {
		$infos{serie} = $1;
		$infos{season} = $2;
		$infos{episode} = $3;
		$infos{serie} =~ s/\./ /g;
		printMessage("debug", "Serie name: ".$infos{serie}.", season: ".$infos{season}.", ep: ".$infos{episode});
	}
	return %infos;
}


##
##
##
sub userSelection {
	my (%hash) = @_;
	my @keys = sort(keys %hash);
	my $max = @keys;
	for (my $i = 0; $i < $max; $i++) {
		my $key = @keys[$i];
		printMessage("question", "[".$i."] ".$key);
	}
	my $item;
	do {
		printMessage("question", "Select a file: [0-".($max-1)."]?");
		chop($item = <STDIN>);
	} until ($item =~ /^\d+$/ && $item>=0 && $item < $max);
	my $selection = $hash{$keys[$item]};
	printMessage("debug", "Selection: ".$selection);
	return $selection;
}

##
##
##
sub downloadTmpFile {
	my ($url) = @_;
	my $document = LWP::Simple::get($url);
	if ($document) {
		my ($tmpFile, $tmpPath) = File::Temp::tempfile();
		$tmpFile->write($document);
		$tmpFile->close();
		printMessage("debug", "File successfully downloaded: ".$url." --> ".$tmpPath);
		return $tmpPath;
	} else {
		printMessage("debug", "Error getting url: ".$url);
	}
}
	
##
##
##
sub computeTargetSrtFile {
	my ($file) = @_;
	$file =~ s/[^\.]*$//;
	$file =~ s/$/srt/;
	printMessage("debug", "Target srt: ".$file);
	return $file;
}

##
##
##
sub convertSubtitleToUTF8 {
	my ($srtPath) = @_;
	my $magic = `file $srtPath`;
	unless ($magic =~ /utf-8/i) {
		my ($tmpFile, $tmpPath) = File::Temp::tempfile();
		printMessage("debug", "Backup srt file: ".$tmpPath);
		File::Copy::copy($srtPath, $tmpPath);
		my $srtFile = FileHandle->new($srtPath, "w");
		my $tmpFile = FileHandle->new($tmpPath, "r");
		my $converter = Text::Iconv->new("iso-8859-1", "utf-8");
		while (my $line = <$tmpFile>) {
			$line = $converter->convert($line);
			$srtFile->write($line);
		}
		printMessage("info", "Subtitle has been converted into UTF8");
		$tmpFile->close();
		$srtFile->close();
	} else {
		printMessage("info", "Subtitle is already UTF8");
	}
}

##
## Removes tags from srt
##
sub removeTagFromSubtitle {
	my ($srtPath) = @_;
	my ($tmpFile, $tmpPath) = File::Temp::tempfile();
	printMessage("debug", "Backup srt file: ".$tmpPath);
	File::Copy::copy($srtPath, $tmpPath);
	my $srtFile = FileHandle->new($srtPath, "w");
	my $tmpFile = FileHandle->new($tmpPath, "r");
	my $nbTags = 0;
	while (my $line = <$tmpFile>) {
		$line =~ s/<[^>]*>//g and $nbTags++;
		$line =~ s/\{[^\}].*\}//g and $nbTags++;
		$srtFile->write($line);
	}
	printMessage("info", "Clean subtitle: ".$nbTags." tag(s) removed");
	$tmpFile->close();
	$srtFile->close();
}

##
##
##
sub unzipInTmpDir {
	my ($zipPath) = @_;
	my $zipObject = Archive::Extract->new(archive => $zipPath, type => 'zip') or die "Error openning zip:".$zipPath;
	my $tmpDir = File::Temp::tempdir();
	printMessage("debug", "Extract zip: ".$zipPath.", to folder:".$tmpDir);
	$zipObject->extract(to => $tmpDir);
	my @content = findSrtInFolder($tmpDir);
	@content;
}


##
##
##
sub displayHelp {
    print"\
NAME
    subdl - Subtitle downloader version 1.1

USAGE
    subdl --verbose --(no)force --(no)autopack --(no)autosrt --(no)clean 
           --(no)utf8 --site=(steu|tvnet) --lang=(fr|en) <EPISODE> ...

OPTIONS
    --help
        Diplay this message.

    -f, --force
    --noforce   (default)
        To force srt download even if srt file is already present.
        By default if a srt file is present, nohting will be done.

    -v, --verbose 
        To display debug informations.

    --autopack   (default)
    --noautopack 
        Automatically try to fetch the pack of subtitles corresponding to the 
        given episode from its number.
        If no result, try --allzip to show all available srt zip files.
    
    --autosrt   (default)
    --noautosrt
        Automatically try to choose the srt that better matches the episode 
        name using the Levenshtein distance.

    -c, --clean   (default) 
    --noclean 
        Cleans (or not) tags if the srt files has some.

    -u, --utf8   (default)
    --noutf8 
        Converts the srt file encoding to utf8.
    
    --site=(steu|tvnet)   
        default=steu
        Set the site to use to get subtitles. Available sites are 
         * www.sous-titres.eu (steu)
         * www.tvsubtitles.net (tvnet)
    
    --lang=(fr|en)   
        default=fr
        The lang of the subtitles to fetch.

EXAMPLES
    subdl --force --verbose --clean My.Serie.S02E04.mkv
        Automatically try to download subtitles for the episode 2x04.
        Then choose the better one. 
        Finally, the srt file will get its tags removed.
        Note: if a My.Serie.S02E04.srt already exists, it will be overwritten.

COPYRIGHT
    Copyright 2011 essembeh.org
    Licence GPLv2.
";
}

package Subdl::site::sous_titres_eu;

##
## Variables
##
our ($URL_PREFIX, $LEVENSHSTEIN_OPTIM);
$URL_PREFIX = "http://www.sous-titres.eu/series/";


##
## Constructor
##
sub new {
	my $this = shift;
	my $class = ref($this) || $this;
	my $self = {};
	bless $self, $class;

	# Set lang for Levenshtein optimisation
	my $lang = shift;
	if ($lang eq "fr") {
		$LEVENSHSTEIN_OPTIM=".vf.fr"
	} elsif ($lang eq "en") {
		$LEVENSHSTEIN_OPTIM=".vo.en"
	} else {
		Subdl::common::printMessage("info", "Invalid lang: ".$lang);
	}

	return $self;
}


##
##
##
sub getName {
	return $URL_PREFIX;
}


##
## Get the serie URL on STEU
##
sub getSerieHomepage {
	my ($this, %fileInfos) = @_;
	my $serieName = $fileInfos{serie};
	$serieName =~ tr/[A-Z]/[a-z]/; 
	$serieName =~ s/[^a-z0-9]/_/g;
	my $url = $URL_PREFIX.$serieName.".html";
	Subdl::common::printMessage("debug", "Serie Homepage: ".$url);
	return $url;
}

##
## Get all zip corresponding the
##
sub getAllPackForSerie {
	my ($this, %fileInfos) = @_;
	my $serieHomepage = $this->getSerieHomepage(%fileInfos);
	my %listOfPacks;
	my $html = LWP::Simple::get($serieHomepage);
	if ($html) {
		$html =~ tr/\r\n//d;
		my @links = $html =~ m/href="(.*?\.zip)"/g;
		foreach my $currentPack (@links) {
			my $packUrl = $URL_PREFIX.$currentPack;
			my $packName = Subdl::common::basename($currentPack);
			Subdl::common::printMessage("debug", "Found pack: ".$packName);
			$listOfPacks{$packName} = $packUrl;
		}
	} else {
		Subdl::common::printMessage("error", "Cannot get page: ".$serieHomepage);
	}
	return %listOfPacks;
}

##
##
##
sub autoChoosePack {
	my ($this, $season, $episode, %listOfPacks) = @_; 
	my $pattern = sprintf("%dx%02d", $season, $episode);
	my $selectedPack; 
	while ( my ($key, $value) = each(%listOfPacks) ) { 
		if ($key =~ /$pattern/) {
			Subdl::common::printMessage("debug", "Auto choose pack: ".$key);
			return $value;
		}   
	}   
	Subdl::common::printMessage("error", "Cannot find a valid pack (use --noautopack to pick one manually)");
}

##
##
##
sub getAllSubtitlesForPack {
	my ($this, $packUrl) = @_;
	# Download the pack
	my $tmpFile = Subdl::common::downloadTmpFile($packUrl);
	# Unzip the pack
	my @content = Subdl::common::unzipInTmpDir($tmpFile);
	my %content;
	foreach my $srtFile (@content) {
		my $basename = Subdl::common::basename($srtFile);
		$content{$basename} = $srtFile;
	}
	return %content;
}

##
##
##
sub autoChooseSubtitle {
	my ($this, $referenceString, %listOfSubtitles) = @_;
	my $bestDistance = -1;
	my $bestKey;
	my $bestValue;
	while ( my ($key, $value) = each(%listOfSubtitles) ) {
		my $distance = Subdl::common::distance($referenceString.$LEVENSHSTEIN_OPTIM, $key);
		Subdl::common::printMessage("debug", "Distance: ".$distance." for srt: ".$key);
		if ($bestDistance < 0 || $distance < $bestDistance) {
			$bestKey = $key;
			$bestValue = $value;
			$bestDistance = $distance;
		}
	}
	Subdl::common::printMessage("debug", "Auto choose srt: ".$bestKey);
	return $bestValue;
}


 
## 
## 
## 
sub copySubtitle () { 
	my ($this, $source, $destination) = @_; 
	Subdl::common::printMessage("info", "Copying: ".Subdl::common::basename($source)); 
	File::Copy::copy($source, $destination); 
}

package Subdl::site::tvsubtitles_net;

##
## Variables
##
our ($URL_PREFIX, $VALID_LANG);
$URL_PREFIX = "http://www.tvsubtitles.net/";



##
## Constructor
##
sub new {
	my $this = shift;
	my $class = ref($this) || $this;
	my $self = {};
	bless $self, $class;

	# Set lang for Levenshtein optimisation
	$VALID_LANG = shift;
	return $self;
}


##
##
##
sub getName {
	return $URL_PREFIX;
}


##
## Get the serie URL on STEU
##
sub getSerieHomepage {
	my ($this, %fileInfos) = @_;
	my $url;
	my $html = LWP::Simple::get($URL_PREFIX."tvshows.html"); 
	if ($html) {
		my $serieName = $fileInfos{serie};
		my %allSeries = $html =~ m@<a href="tvshow-(\d+)-\d+\.html">(.*?)</a>@g;
		while (my ($id, $name) = each (%allSeries)) {
			if ($name =~ /$serieName/i) {
				Subdl::common::printMessage("debug", "Found serie on site");
				$url = $URL_PREFIX."tvshow-".$id."-".$fileInfos{season}.".html";
				last;
			}
		}
	}
	Subdl::common::printMessage("debug", "Serie homepage: ".$url);
	return $url;
}


##
## Get all zip corresponding the
##
sub getAllPackForSerie {
	my ($this, %fileInfos) = @_;
	my $serieHomepage = $this->getSerieHomepage(%fileInfos);
	my %listOfPacks;
	my $html = LWP::Simple::get($serieHomepage);
	if ($html) {
		$html =~ tr/\r\n//d;
		my %allEp = $html =~ m@<tr.*?>.*?<td>(\d+x\d+)</td>.*?<a href="(episode-\d+).html">.*?</tr>@g;
		while (my ($ep, $url) = each (%allEp)) {
			my $link = $URL_PREFIX.$url."-".$VALID_LANG.".html";
			$listOfPacks{$ep} = $link;
			Subdl::common::printMessage("debug", "Found pack: ".$ep." -> ".$link);
		}
	}
	return %listOfPacks;
}


##
##
##
sub autoChoosePack {
	my ($this, $season, $episode, %listOfPacks) = @_; 
	my $pattern = sprintf("%dx%02d", $season, $episode);
	my $selectedPack;
	while ( my ($key, $value) = each(%listOfPacks) ) {
		if ($key =~ /$pattern/) {
			Subdl::common::printMessage("debug", "Auto choose pack: ".$key);
			return $value;
		}
	}
	Subdl::common::printMessage("error", "Cannot find a valid pack (use --noautopack to pick one manually)");
}


##
##
##
sub getAllSubtitlesForPack {
	my ($this, $packUrl) = @_;
	my $html = LWP::Simple::get($packUrl);
	my %content;
	if ($html) {
		$html =~ tr/\r\n//d;
		my %allSubs = $html =~ m@<a href="/subtitle-(\d+)\.html">.*?<h5.*?>(.*?)</h5>.*?</a>@g;
		while (my($id, $name) = each(%allSubs)) {
			$name =~ s/<.*?>//g;
			my $srtUrl = $URL_PREFIX."download-".$id.".html";
			if ($content{$name}) {
				Subdl::common::printMessage("warn", "Multiple subtitles with the same name");
				Subdl::common::printMessage("debug", "Ignoring srt: ".$name." -> ".$srtUrl);
			} else {
				Subdl::common::printMessage("debug", "Found srt: ".$name." -> ".$srtUrl);
				$content{$name} = $srtUrl;
			}
		}
	}
	return %content;
}


##
##
##
sub autoChooseSubtitle {
	my ($this, $referenceString, %listOfSubtitles) = @_;
	my $bestDistance = -1;
	my $bestKey;
	my $bestValue;
	while ( my ($key, $value) = each(%listOfSubtitles) ) {
		my $distance = Subdl::common::distance($referenceString, $key);
		Subdl::common::printMessage("debug", "Distance: ".$distance." for srt: ".$key);
		if ($bestDistance < 0 || $distance < $bestDistance) {
			$bestKey = $key;
			$bestValue = $value;
			$bestDistance = $distance;
		}
	}
	Subdl::common::printMessage("debug", "Auto choose srt: ".$bestKey);
	return $bestValue;
}


## 
## 
## 
sub copySubtitle () { 
	my ($this, $zipUrl, $destination) = @_; 
	my $zipFile = Subdl::common::downloadTmpFile($zipUrl);
	my @content = Subdl::common::unzipInTmpDir($zipFile);
	my $first = $content[0];
	File::Copy::copy($first, $destination);
	Subdl::common::printMessage("info", "Copying: ".Subdl::common::basename($first));
}

package Subdl::main;

our ($VERBOSE);

## Get options from command line
my $optionAutopack = 1;
my $optionAutosrt  = 1; 
my $optionForce    = 0; 
my $optionClean    = 1; 
my $optionUtf8     = 1;
my $optionSite     = 'steu'; 
my $optionLang     = 'fr'; 
my $optionHelp     = 0; 
unless (Getopt::Long::GetOptions(	"v|verbose"  => \$VERBOSE, 
									"f|force!"   => \$optionForce, 
									"autosrt!"   => \$optionAutosrt, 
									"autopack!"  => \$optionAutopack, 
									"u|utf8!"    => \$optionUtf8,
									"c|clean!"   => \$optionClean,
									"site=s"     => \$optionSite,
									"lang=s"     => \$optionLang,
									"help"       => \$optionHelp
									)) {
	Subdl::common::displayHelp();
	exit 1;
}
# Check if help requested
if ($optionHelp) {
	Subdl::common::displayHelp();
	exit 0;
}


# Check site
my $site;
if ($optionSite eq "steu") {
	$site = Subdl::site::sous_titres_eu->new($optionLang);
} elsif ($optionSite eq "tvnet") {
	$site = Subdl::site::tvsubtitles_net->new($optionLang);
} else {
	Subdl::common::printMessage("error", "Invalid site: ".$optionSite);
	exit 2;
}
Subdl::common::printMessage("debug", "Using site: ".$site->getName());

# Main loop
my $count = 0;
foreach my $file (@ARGV) {
	Subdl::common::printMessage() if ($count ++);
	Subdl::common::printMessage("info", "Fetching srt for episode: ".$file);
	
	## Step 0: Compute srt target file
	my $targetSrtFile = Subdl::common::computeTargetSrtFile($file);
	if (-f $targetSrtFile) {
		if ($optionForce) {
			Subdl::common::printMessage("info", "Srt already exists, will be overwritten");
		} else {
			Subdl::common::printMessage("error", "The srt file already exists (use --force to overwrite)");
			next;
		}
	}

	## Step 1: File information
	my %fileInfos = Subdl::common::getInformationFromEpisodeName($file);
	unless (%fileInfos) {
		Subdl::common::printMessage("error", "Error getting informations from filename: ".$file);
		next;
	}
	
	## Step 2a: Get all zip
	my %listOfPacks = $site->getAllPackForSerie(%fileInfos);
	unless (%listOfPacks) {
		Subdl::common::printMessage ("error", "Cannot find any pack for the serie");
		next;
	}

	## Step 2b: Choose a pack
	my $selectedPackUrl;
	if ($optionAutopack) {
		$selectedPackUrl = $site->autoChoosePack($fileInfos{season}, $fileInfos{episode}, %listOfPacks);
	} else {
		$selectedPackUrl = Subdl::common::userSelection(%listOfPacks);
	}
	next unless ($selectedPackUrl);

	## Step 3a: Get srt list
	my %listOfSubtitles = $site->getAllSubtitlesForPack($selectedPackUrl);
	unless (%listOfSubtitles) {
		Subdl::common::printMessage("error", "No srt found for selected pack");
		next;
	}
		
	## Step 3b: Choose a srt
	my $selectedSubtitleUrl;
	if ($optionAutosrt) {
		$selectedSubtitleUrl = $site->autoChooseSubtitle ($targetSrtFile, %listOfSubtitles);
	} else {
		$selectedSubtitleUrl = Subdl::common::userSelection (%listOfSubtitles);
	}
	next unless ($selectedSubtitleUrl);

	## Step 4: Copy the srt
	$site->copySubtitle($selectedSubtitleUrl, $targetSrtFile);

	## Step 5a: Clean the srt
	if ($optionClean) {
		Subdl::common::removeTagFromSubtitle($targetSrtFile);
	}

	## Step 5b: Convert to UTF8
	if ($optionUtf8) {
		Subdl::common::convertSubtitleToUTF8($targetSrtFile);
	}
}

