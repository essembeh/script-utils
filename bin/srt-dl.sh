#!/bin/bash

## Binaries
MKTEMP_BIN=`which mktemp` || exit 1
AWK_BIN=`which awk` || exit 1
SED_BIN=`which sed` || exit 1
GREP_BIN=`which egrep` || exit 1
WGET_BIN=`which wget` || exit 1
BASENAME_BIN=`which basename`|| exit 1
DIRNAME_BIN=`which dirname`|| exit 1
UNZIP_BIN=`which unzip` || exit 1
CP_BIN="`which cp` -vi" || exit 1

## CONSTANTS
STEU_URL="http://www.sous-titres.eu/series"
STEU_DISCRIM='class="subList"'

## Options
VERBOSE="false"
FILTER_EPNUMBER="true"
FORCE_OVERWRITE="false"

##
## Prints log
##
__log () {
	test "$VERBOSE" = "true" && echo "$@"
}

##
## Get the serie identifier on soust-titres.eu
##
__getSerieIdentifier () {
	$BASENAME_BIN "$1" | $AWK_BIN '{print tolower($0)}' | $SED_BIN -r -e "s/[\. ]/_/g"
}

##
## Get the serie URL on STEU
##
__getSerieHomepage () {
	serieID=`__getSerieIdentifier "$1"`
	serieURL="$STEU_URL/$serieID.html"
	echo "$serieURL"
}

##
## Get the serie from filename
##
__getEpisodeNumber () {
	$BASENAME_BIN "$1" | $SED_BIN -e "s@^.*[\. ][sS]\([0-9]\+\)[eE]\([0-9]\+\).*@\1x\2@" -e "s/^0\+//"
}
##
## Get the serie from filename
##
__getSerieNameFromFile () {
	$BASENAME_BIN "$1" | $SED_BIN "s@^\(.*\)[\. ][sS][0-9]\+[eE][0-9]\+.*@\1@"
}

##
## Get Zip URL
##
__getZipUrls () {
	htmlFile=`$MKTEMP_BIN`
	if $WGET_BIN "$1" -qO $htmlFile; then
		$GREP_BIN $STEU_DISCRIM $htmlFile | $SED_BIN 's/^.*href="\(.*\.zip\)".*$/\1/' | $GREP_BIN "$2"
	else
		return 1
	fi
}

##
## Download SRT and prints paths
##
__getSrtFromUrl () {
	tmpZipFile=`$MKTEMP_BIN`
	if $WGET_BIN "$1" -qO "$tmpZipFile"; then
		tmpFolder=`$MKTEMP_BIN -d`
		if $UNZIP_BIN -qd $tmpFolder $tmpZipFile; then
			find $tmpFolder -name "*.srt" | sort
		else
			return 2
		fi
	else
		return 1
	fi
}

##
## File selector
##
__fileSelection () {
	fileCount=`echo "$1" | wc -l`
	__log "File count: $fileCount"
	if [ $fileCount -eq 0 ]; then
		return 1
	elif [ $fileCount -eq 1 ]; then
		returnedFile="$1"
	else
		i=1
		echo "$1" | while read currentFile; do 
			fileBasename=`$BASENAME_BIN "$currentFile"`
			echo "[$i] $fileBasename"
			i=`expr $i + 1`
		done
		answer=0
		while [ $answer -lt 1 -o $answer -gt $fileCount ]; do
			echo "Enter a file ? [1-$fileCount]"
			read answer
		done
		returnedFile=`echo "$1" | $SED_BIN -n "${answer}p"`
	fi
}

##
## Guess the SRT Name
##
__computeSrtFilename () {
	srtFile=`echo "$1" | $SED_BIN -e "s/[[:alnum:]]\+$//" -e "s/$/srt/"`
	echo "$srtFile"
	test -f "$srtFile" && return 1
}

## 
## man
##
__usage () {
	echo "NAME"
	echo "    srt-dl - Sub title downloader"
	echo ""
	echo "USAGE"
	echo "    srt-dl [OPTIONS] <EPISODE> <EPISODE> ..."
	echo ""
	echo "OPTIONS"
	echo "    -h, --help"
	echo "        Diplay this message"
	echo "    -f, --force"
	echo "        Force srt download even if srt file is already present"
	echo "    -v, --verbose "
	echo "        More verbose"
	echo "    -a, --all"
	echo "        Propose the choice of the zip file, does not filter with episode number"
}

## 
## Main 
##
__main () {
	for currentEpisode in "$@"; do 
		episodeName=`$BASENAME_BIN "$currentEpisode"`
		echo "Find SRT for File: $episodeName"
		targetSrtFile=`__computeSrtFilename "$currentEpisode"`
		__log "SRT target: $targetSrtFile"
		if test -f "$targetSrtFile"; then
			echo "     The srt file already exists: $targetSrtFile"
			test "$FORCE_OVERWRITE" = "true" || continue
		fi
		serieName=`__getSerieNameFromFile "$episodeName"`
		__log "Serie name: $serieName"
		serieHomepage=`__getSerieHomepage "$serieName"` 
		__log "Serie homepage: $serieHomepage"
		episodeNumber=`__getEpisodeNumber "$episodeName"`
		__log "Episode number: $episodeNumber"
		if [ "$FILTER_EPNUMBER" = "true" ]; then
			listOfZipFiles=`__getZipUrls "$serieHomepage" "$episodeNumber"`
		else
			listOfZipFiles=`__getZipUrls "$serieHomepage"`
		fi
		if [ ! $? -eq 0 ]; then
			echo " *** Error getting subtitles for episode: $episodeNumber, on page: $serieHomepage"
			continue
		fi
		__fileSelection "$listOfZipFiles"
		if [ ! $? -eq 0 ]; then
			echo "*** Error getting subtitles for episode: $episodeNumber, on page: $serieHomepage"
			continue
		fi
		zipFile="$returnedFile"
		__log "Selected ZIP file: $zipFile"
		listOfSrtFiles=`__getSrtFromUrl "$STEU_URL/$returnedFile"`
		__fileSelection "$listOfSrtFiles"
		if [ ! $? -eq 0 ]; then
			echo " *** Error downloading ZIP: $zipFile"
			continue
		fi
		srtFile="$returnedFile"
		__log "SRT file: $srtFile"
		$CP_BIN "$srtFile" "$targetSrtFile"
	done
}

endOfLoop="false"
while [ "$endOfLoop" = "false" ]; do
	case "$1" in 
		"-a" | "--all")
			echo "+++ Do not filter zip file with episode number"
			FILTER_EPNUMBER="false"
			shift;;
		"-f" | "--force")
			echo "+++ Force srt even if the srt file already exists"
			FORCE_OVERWRITE="true"
			shift;;
		"-v" | "--verbose")
			echo "+++ Verbose mode"
			VERBOSE="true"
			shift;;
		"-h" | "--help")
			__usage 
			exit 0;;
		"-"*)
			__usage 
			exit 1;;
		*)
			endOfLoop="true";;
	esac
done
__main $@
