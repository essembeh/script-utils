#!/usr/bin/perl 
##
## srt-dl a tool to download srt.
##
##
## Dependencies (for Debian GNU/Linux): 
##   apt-get install libwww-perl libtext-levenshtein-perl
## Using cpan:
##   install Text::Levenshtein 
##
package org::essembeh::script;

use strict;
use LWP::Simple;
use File::Basename;
use Archive::Zip;
use Getopt::Long;
use Text::Levenshtein qw(distance);
use File::Temp qw/:POSIX/;
use File::Copy;


our (%OPTIONS, $STEU_PREFIX, $LEVENSHSTEIN_OPTIM);
$STEU_PREFIX = "http://www.sous-titres.eu/series/";
$LEVENSHSTEIN_OPTIM = "fr.vf";


##
## Log message if verbose mode is set
##
sub printMessage {
	my $type = $_[0];
	unless ($type) {
		print "\n";
	} elsif ($OPTIONS{"verbose"} || $type ne "debug") {
		for (my $i = 1; $i < @_; $i++) {
			$type = "[".$type."]";
			printf("%10s %s\n", $type, $_[$i]);
		}
	}
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
	$str =~ s/[sS](?:0*)([0-9]+)[eE]([0-9]+)/$1$2/;
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
## Get the serie identifier on soust-titres.eu
##
sub getSerieIdentifier {
	my $serieName=$_[0];
	my $serieId = $serieName;
	$serieId =~ tr/[A-Z]/[a-z]_/; 
	$serieId =~ tr/ ./_/;
	&printMessage("debug", "Serie identifier: : ".$serieId);
	$serieId;
}

##
## Get the serie URL on STEU
##
sub getSerieHomepage {
	my $serieName = $_[0];
	my $url = $STEU_PREFIX.&getSerieIdentifier($serieName).".html";
	&printMessage("debug", "Serie Homepage: ".$url);
	$url;
}

##
## Get Episode number
##
sub getEpisodeNumber {
	my $episode = $_[0];
	my $number = $episode;
	if ($episode =~ /.*[sS](\d+)[eE](\d+).*/) {
		$number = $1."x".$2;
		$number =~ s/^0//;
		&printMessage("debug", "Episode number: ".$number);
		$number;
	} else {
		undef;
	}
}

##
## Retreives the serie name from a filename
##
sub getSerieNameFromFile {
	my $name = &myBasename($_[0]);
	$name =~ s@[\. ][sS]\d+[eE]\d+.*@@;
	&printMessage("debug", "Serie name: ".$name);
	$name;
}

##
## Get all zip corresponding the
##
sub getZipFileInPage {
	my $url=$_[0];
	my $filter = $_[1];
	my @zipFiles;
	my $html = get($url);
	if ($html) {
		my @html = split("\n", $html);
		foreach my $line (@html) {
			if ($line =~ /href=.(.*\.zip)/) {
				my $zipUrl=$1;
				if ($OPTIONS{"allzip"} || $zipUrl =~ /$filter/) {
					push(@zipFiles, $zipUrl);
				}
			}
		}
	}
	if (@zipFiles > 0) {
		&selectInList(@zipFiles);
	}
}

##
##
##
sub selectInList {
	my $max = @_;
	if ($max > 1) {
		@_ = sort { &myBasename($a) cmp &myBasename($b) } @_;
		for (my $i = 0; $i < $max; $i++) {
			my $file = &myBasename($_[$i]);
			&printMessage("question", "[".$i."] ".$file);
		}
		my $item;
		do {
			&printMessage("question", "Select a file: [0-".($max-1)."]?");
			chop($item = <STDIN>);
		}until ($item =~ /^\d+$/ && $item>=0 && $item < $max);
		$_[$item];
	} else {
		$_[0];
	}
}

##
##
##
sub downloadFileInTmp {
	my $url = $_[0];
	my $document = get($url);
	if ($document) {
		my $tmpPath = tmpnam();
		my $tmpFile = FileHandle->new($tmpPath, "w");
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
sub extractSrtFromZip {
	 my $zipPath = $_[0];
	 my $target = $_[1];
	 my $zipObject = Archive::Zip->new($zipPath) or die "Error openning zip:".$zipPath;
	 my @content;
	 my $betterFile;
	 my $betterDistance = 0;
	 my $targetOptim = $target;
	 &printMessage("debug", "Opening zip: ".$zipPath);
	 $targetOptim =~ s/srt$/$LEVENSHSTEIN_OPTIM.srt/;
	 &printMessage("debug", "Target for distance computing: ".$targetOptim);
	 foreach my $member ($zipObject->members) {
		 my $filename = $member->fileName();
		 if ($filename =~ /srt$/) {
			my $distance = &myDistance($filename, $targetOptim);
			unless ($OPTIONS{"allsrt"}) {
				if (!$betterFile || abs($distance) < $betterDistance) {
					$betterFile = $filename;
					$betterDistance = abs($distance);
				}
			}
			push(@content, $filename);
		 }
	 }
	 if ($OPTIONS{"allsrt"}) {
		 $betterFile = &selectInList(@content);
	 } else {
		 &printMessage("debug", "Auto choosing file: ".$betterFile." with distance: ".$betterDistance);
	 }
	 $zipObject->extractMember($betterFile, $target);
	 &printMessage("info", "File copied: ".$betterFile);
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
sub removeTag {
	my $srtPath = $_[0];
	my $tmpPath = tmpnam();
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
	&printMessage("debug", "Tags removed: ".$nbTags);
	$tmpFile->close();
	$srtFile->close();
}


##
##
##
sub displayHelp {
    print"NAME
    srt-dl - Sub title downloader version 1.0

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

    --allzip 
    --noallzip (default)
        Automatically try to fetch the zip corresponding to the 
        given episode from its number.
        If no result, try --allzip to show all available srt zip files.
    
    --allsrt 
    --noallsrt (default)
        Automatically try to choose the srt that better matches the episode 
        name using the Levenshtein distance.

    -c, --clean 
    --noclean (default)
        Clean tags if the srt files has some.

EXAMPLES
    srt-dl --force --verbose --clean My.Serie.S02E04.mkv
        Automatically try to dl zip for the episode 2x04.
        Then choose the better SRT. 
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

unless (GetOptions(\%OPTIONS, "help", "verbose", "force", "allzip", "allsrt", "clean")) {
	displayHelp;
	exit 1;
}

if ($OPTIONS{"help"}) {
	displayHelp;
	exit 0;
}

my $firstLoop = 1;
foreach my $episode (@ARGV) {
	if ($firstLoop) {
		$firstLoop = 0;
	} else {
		&printMessage();
	}
	&printMessage("info", "Fetching srt for episode: ".$episode);
	my $target=&computeTargetSrtFile($episode);
	if (-f $target) {
		if (!$OPTIONS{"force"}) {
			&printMessage("error", "The srt file already exists");
			next;
		} else {
			&printMessage("debug", "Srt already exists");
		}
	}
	my $serie = &getSerieNameFromFile($episode);
	unless ($serie) {
		&printsage("error", "Error getting the serie name");
		next;
	}
	my $url = &getSerieHomepage($serie);
	unless ($url) {
		&printMessage("error", "Error getting serie homepage");
		next;
	}
	my $episodeNumber = &getEpisodeNumber($episode);
	unless ($episodeNumber) {
		&printMessage("warning", "Cannot retrieve episode number");
	}
	my $zipUrl = &getZipFileInPage($url, $episodeNumber);
	unless ($zipUrl) {
		&printMessage("error", "No zip file found");
		next;
	}
	my $zipFile = &downloadFileInTmp($STEU_PREFIX.$zipUrl);
	unless ($zipFile) {
		&printMessage("error", "Error downloading zip file: ".$zipUrl);
		next;
	}
	&extractSrtFromZip($zipFile, $target);
	if ($OPTIONS{"clean"}) {
		&removeTag($target);
	}
}

