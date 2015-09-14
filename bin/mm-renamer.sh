#!/bin/bash

HASH_BIN=sha1sum
EXIFTOOL_BIN=exiftool
DATE_FORMAT="%Y%m%d-%H%M%S"


__init () {
	$HASH_BIN --version > /dev/null 2>&1
	if test $? -ne 0; then
		echo "Error with hash binary: $HASH_BIN"
		exit 1
	fi
	$EXIFTOOL_BIN --version > /dev/null 2>&1
	if test $? -ne 0; then
		echo "Error with exiftool binary: $EXIFTOOL_BIN"
		exit 1
	fi
}

__usage () {
echo "NAME
	mm-renamer - Tool to rename files using exif and hash

USAGE
	mm-renamer --date --dry-run --hash-len=12 --lower-ext *.JPG
	mm-renamer -d -n -s 12 -l *.JPG
	mm-renamer --date --jpg *.JPG
	mm-renamer --keep-name --date --lower-ext *.JPG

OPTIONS
	-h, --help
		Diplay this message.

	-n, --dry-run
		Dry run, files are not renamed

	-d, --date
		Prefix the filename with the date if present in the exif metadata
		Works with jpg/png/mp4/mov/... files
		Uses exiftool to read exif metadata

	-s, --hash-len=N
		Uses N chars of the hash

	-k, --keep-name
		Use file name instead of the hash

	-l, --lower-ext
		Lower case the extension

	--jpg, --png, --nef, --avi, --mkv, --mp4, --mov, --xml
		Use the given extension

EXAMPLES
	mm-renamer.sh --date test.JPEG
	( )  test.JPEG -> ./20140224-133158_53c8d09.JPEG

	mm-renamer.sh --date --keep-name --lower-ext test.JPEG
	( )  test.JPEG -> ./20140224-133158_test.jpeg

	mm-renamer.sh --date --hash-len=12 --jpg test.JPEG
	( )  test.JPEG -> ./20140224-133158_53c8d09c2e45.jpg

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

__getHash () {
	HASH=$($HASH_BIN "$1" 2> /dev/null)
	if test $? -ne 0 -o -z "$HASH"; then
		return 1
	fi
	HASH=$(echo "$HASH" | awk '{print $1}')
	if test "$OPTION_HLEN" -eq 0; then
		echo "$HASH"
	else
		echo "$HASH" | head -c "$OPTION_HLEN"
	fi
}

__getTimeStamp () {
	OUT=$($EXIFTOOL_BIN -modifyDate -s3 -d "$DATE_FORMAT" "$1" 2>/dev/null)
	test -z "$OUT" && \
		OUT=$($EXIFTOOL_BIN -createDate -s3 -d "$DATE_FORMAT" "$1" 2>/dev/null)
	echo "$OUT"
}


__init

OPTION_KEEPNAME=false
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
		-s)
			shift; OPTION_HLEN=$1 ;;
		--hash-len=?*)
			OPTION_HLEN=${1#--hash-len=} ;;
		--keep-name|-k)
			OPTION_KEEPNAME=true ;;
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
	if test ! -e "$FILE"; then
		__customOut blue
		echo "(/)  Problem with: $FILE"
		continue
	fi
	DIRNAME=$(dirname "$FILE")
	BASENAME=$(basename "$FILE")
	OLDNAME="$DIRNAME/$BASENAME"
	EXTENSION="${BASENAME##*.}"
	FILENAME="${BASENAME/%.$EXTENSION/}"
	if test -z "$FILENAME"; then
		FILENAME="$BASENAME"
		EXTENSION=""
	fi
	TIMESTAMP=$(__getTimeStamp "$FILE")
	NEWNAME=""
	test -n "$TIMESTAMP" -a "$OPTION_DATE" = "true" && NEWNAME="${TIMESTAMP}_"
	if "$OPTION_KEEPNAME" = "true"; then
		NEWNAME="$NEWNAME$FILENAME"
	else
		HASH=$(__getHash "$FILE")
		if test -z "$HASH"; then
			__customOut blue
			echo "(/)  Cannot compute hash for: $OLDNAME"
			continue
		fi
		NEWNAME="$NEWNAME$HASH"
	fi
	if test -n "$OPTION_EXT"; then
		NEWNAME="$NEWNAME.$OPTION_EXT"
	elif test -n "$EXTENSION"; then
		test "$OPTION_LCEXT" = "true" && EXTENSION=$(echo -n "$EXTENSION" | awk '{print tolower($1)}')
		NEWNAME="$NEWNAME.$EXTENSION"
	fi
	NEWNAME="$DIRNAME/$NEWNAME"
	if test "$OLDNAME" = "$NEWNAME"; then
		__customOut reset
		echo "Already named: $OLDNAME"
	elif test "$OPTION_DRYRUN" = "true"; then
		__customOut yellow
		echo "dry-run $FILE --> $NEWNAME"
	elif test -f "$NEWNAME"; then
		__customOut red
		mv -n -v "$FILE" "$NEWNAME.$RANDOM"
	else
		__customOut green
		mv -n -v "$FILE" "$NEWNAME"
	fi
done
