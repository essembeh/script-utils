#!/usr/bin/perl 
use strict;

require FileHandle; 
require URI::Escape;
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
sub displayHelp {
    print"\
NAME
    iTunesOrphans - iTunes orphan finder

USAGE
    iTunesOrphans 

OPTIONS
    --help
        Diplay this message.

    -v, --verbose 
        To display debug informations.

COPYRIGHT
    Copyright 2011 essembeh.org
    Licence GPLv2.
";
}

sub decode {
	my ($file) = @_;
	$file = URI::Escape::uri_unescape($file);
	$file =~ s/&#38;/&/g;
	return $file;
}

## Get options from command line
my $optionHelp     = 0; 
unless (Getopt::Long::GetOptions(	"v|verbose"  => \$VERBOSE, 
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
my $iTunesDB = $ENV{'HOME'}."/Music/iTunes/iTunes Music Library.xml";
printMessage("debug", "iTunes DB: ".$iTunesDB);
my FileHandle $db = FileHandle->new($iTunesDB, "r") or die "Cannot open itunes db: ".$iTunesDB;
my @allFiles;
while (chop(my $line = $db->getline())) {
	if ($line =~ m@<key>Location</key><string>file://localhost(.*)</string>@) {
		my $fileURI = $1;
		if ($fileURI) {
			push(@allFiles, decode($fileURI));
		}
	}
}
$db->close();

printMessage("info", "iTunesDB contains ".@allFiles." file(s)");

foreach my $song (@allFiles) {
	if (-f $song) {
		printMessage("debug", "File exists: ".$song);
	} else {
		printMessage("error", "File does not exists: ".$song);
	}
}

