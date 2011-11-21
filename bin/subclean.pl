#!/usr/bin/perl 
use strict;

require File::Temp; 
require File::Copy; 
require FileHandle; 
require Text::Iconv;
require Getopt::Long;


our ($VERBOSE);

##
## Log message if verbose mode is set
##
sub printMessage {
	my ($type) = @_;
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
sub convertSubtitleToUTF8 {
	my ($srtPath) = @_;
	my $magic = `file $srtPath`;
	unless ($magic =~ /utf-?8/i) {
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
		printMessage("debug", "Subtitle is already UTF8");
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
	my $level = "debug";
	$level = "info" if ($nbTags);
	printMessage($level, "Clean subtitle: ".$nbTags." tag(s) removed");
	$tmpFile->close();
	$srtFile->close();
}

##
##
##
sub displayHelp {
    print"\
NAME
    subclean - Subtitle cleaner version 1.0

USAGE
    subclean --verbose --(no)utf8 --(no)clean  <SUBTITLE> ...

OPTIONS
    --help
        Diplay this message.

    -v, --verbose 
        To display debug informations.

    -c, --clean   (default) 
    --noclean 
        Cleans (or not) tags if the srt files has some.

    -u, --utf8   (default)
    --noutf8 
        Converts the srt file encoding to utf8.

EXAMPLES
    subclean --clean path/sub1.srt path2/*srt

COPYRIGHT
    Copyright 2011 essembeh.org
    Licence GPLv2.
";
}

## Get options from command line
my $optionClean    = 1; 
my $optionUtf8     = 1;
my $optionHelp     = 0; 
unless (Getopt::Long::GetOptions(	"v|verbose"  => \$VERBOSE, 
									"u|utf8!"    => \$optionUtf8,
									"c|clean!"   => \$optionClean,
									"help"       => \$optionHelp
									)) {
	displayHelp();
	exit 1;
}
# Check if help requested
if ($optionHelp) {
	displayHelp();
	exit 0;
}

# Main loop
my $count = 0;
foreach my $file (@ARGV) {
	printMessage() if ($count ++);
	
	## Check srt
	if (! $file =~ /\.srt$/) {
		printMessage("info", "Not a srt file: ".$file);
		next;
	} elsif (! -f $file) {
		printMessage("info", "File does not exist: ".$file);
		next;
	} else {
		printMessage("info", "Cleaning file: ".$file);
	}

	## Clean the srt
	if ($optionClean) {
		removeTagFromSubtitle($file);
	}

	## Convert to UTF8
	if ($optionUtf8) {
		convertSubtitleToUTF8($file);
	}
}

