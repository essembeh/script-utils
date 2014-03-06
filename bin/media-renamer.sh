#!/bin/bash

HASH_BIN=sha1sum
EXIFTOOL_BIN=exiftool
DATE_FORMAT="%Y%m%d-%H%M%S"

__usage () {
echo "NAME
	media-renamer - Tool to rename files using exif and hash

USAGE
	media-renamer --date --dry-run --hash-len=12 --lower-ext *.JPG
	media-renamer -d -n -h 12 -l *.JPG
	media-renamer --date --jpg *.JPG

OPTIONS
	-h, --help
		Diplay this message.

	-n, --dry-run
		Dry run, files are not renamed

	-d, --date
		Prefix the filename with the date if present in the exif metadata
		Works with jpg/png/mp4/mov/... files 
		Uses exiftool to read exif metadata
	
	-h N, --hash-len=N
		Uses N chars of the hash

	-l, --lower-ext
		Lower case the extension
	
	--jpg, --png, --nef, --avi, --mkv, --mp4, --mov, --xml
		Use the given extension
"
}

__customOut() {
    while test $# -gt 0; do
        case $1 in
            black)       tput setaf 0;;
            red)         tput setaf 1;;
            green)       tput setaf 2;;
            yellow)      tput setaf 3;;
            blue)        tput setaf 4;;
            purple)      tput setaf 5;;
            cyan)        tput setaf 6;;
            white)       tput setaf 7;;
            back-black)  tput setab 0;;
            back-red)    tput setab 1;;
            back-green)  tput setab 2;;
            back-yellow) tput setab 3;;
            back-blue)   tput setab 4;;
            back-purple) tput setab 5;;
            back-cyan)   tput setab 6;;
            back-white)  tput setab 7;;
            bold)        tput bold;;
            halfbright)  tput dim;;
            underline)   tput smul;;
            nounderline) tput rmul;;
            reverse)     tput rev;;
            standout)    tput smso;;
            nostandout)  tput rmso;;
            reset)       tput sgr0;;
            *)           tput sgr0;;
        esac
        shift
    done
}

_getHash () {
	HASH=`$HASH_BIN "$1" | awk '{print $1}'`
	if [ $OPTION_HLEN -eq 0 ]; then
		echo $HASH
	else
		echo $HASH | head -c $OPTION_HLEN
	fi
}

_getTimeStamp () {
	$EXIFTOOL_BIN -createDate -s3 -d "$DATE_FORMAT" "$1" 2>/dev/null
}

OPTION_LCEXT=false
OPTION_DATE=false
OPTION_DRYRUN=false
OPTION_EXT=
OPTION_HLEN=7

while test -n "$1"; do
	case $1 in 
		--dry-run|-n)
			OPTION_DRYRUN=true ;;
		--date|-d)
			OPTION_DATE=true ;;
		--hash-len=?*)
			OPTION_HLEN=${1#--hash-len=} ;;
		-h)
			shift; OPTION_HLEN=$1 ;;
		--lower-ext|-l)
			OPTION_LCEXT=true ;;
		--jpg|--png|--nef|--avi|--mkv|--mp4|--mov|--xml)
			OPTION_EXT="${1#--}" ;;
		--help|-h)
			__usage; exit 0;;
		*)	break;;
	esac
	shift
done

__customOut reset
for FILE in "$@"; do 
	DIRNAME="`dirname "$FILE"`"
	BASENAME="`basename "$FILE"`"
	EXTENSION="${BASENAME##*.}"
	TIMESTAMP=`_getTimeStamp "$FILE"` 
	HASH=`_getHash "$FILE"` 
	NEWNAME=""
	test -n "$TIMESTAMP" -a "$OPTION_DATE" = "true" && NEWNAME="${TIMESTAMP}_"
	NEWNAME="$NEWNAME$HASH"
	if test -n "$OPTION_EXT"; then
		NEWNAME="$NEWNAME.$OPTION_EXT"
	elif test -n "$EXTENSION"; then
		test "$OPTION_LCEXT" = "true" && EXTENSION="`echo -n "$EXTENSION" | awk '{print tolower($1)}'`"
		NEWNAME="$NEWNAME.$EXTENSION"
	fi
	NEWNAME="$DIRNAME/$NEWNAME"
	OLDNAME="$DIRNAME/$BASENAME"	
	if test "$OLDNAME" = "$NEWNAME"; then
		__customOut reset
		echo "(!)  Already named: $OLDNAME"
	elif test -f "$NEWNAME"; then
		__customOut red
		echo "(X)  File already exists: $OLDNAME --> $NEWNAME"
	elif test "$OPTION_DRYRUN" = "true"; then
		__customOut green
		echo "(-)  dru-run $FILE --> $NEWNAME"
	else
		__customOut green
		echo -n "( )  "
		mv -n -v "$FILE" "$NEWNAME"
	fi
done

