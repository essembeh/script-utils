#!/bin/sh

BIN=$0
GREP_BIN="`which grep` -E" || exit 1
SED_BIN=`which sed` || exit 1
MV_BIN=`which mv` || exit 1
CP_BIN=`which cp` || exit 1
FIND_BIN=`which find` || exit 1
## MacOS
#MKTEMP_BIN="`which mktemp` -t plop"
## GNU/Linux
MKTEMP_BIN=`which mktemp`


MODE="REPLACE"
PATTERN_TAG1="{[^}]*}"
PATTERN_TAG2="<[^>]*>"

__removeTagsFromFile () {
	FILE="$1"
	TMPFILE="`$MKTEMP_BIN`"
	case "$MODE" in 
		"DRYRUN") 
			echo ""
			return 1;;
		"COPY") 
			TARGET="$FILE.notag";;
		"REPLACE")
			TARGET="$FILE";;
	esac
	$CP_BIN "$FILE" "$TMPFILE"
	$SED_BIN -e "s/$PATTERN_TAG1//g" -e "s/$PATTERN_TAG2//g" < "$TMPFILE" > "$TARGET" 
	echo " -> $TARGET"
}

__testFile () {
	FILE="$1"
	if [ -f "$FILE" ]; then
		echo "$FILE" | $GREP_BIN -q "\.srt$"
		if [ $? -eq 0 ]; then
			$GREP_BIN -q -e "$PATTERN_TAG1" -e "$PATTERN_TAG2" <"$FILE"
			if [ $? -eq 0 ]; then
				echo -n "+++ File contains tag: $FILE"
				return 0
			else
				echo    "--- File has no tag:   $FILE"
				return 3
			fi
		else
			echo "    Not a SRT file:    $FILE"
			return 2
		fi
	else
		echo "    Not a valid file:  $FILE"
		return 1
	fi
}


__processFolder () {
	FOLDER="$1"
	echo "Processing folder: $FOLDER"
	$FIND_BIN "$FOLDER" -type f -name "*.srt" | while read LINE; do 
		__testFile "$LINE" && __removeTagsFromFile "$LINE"
	done
}


__usage () {
	echo "Usage: "$(basename $0)" [OPTIONS] files dirs ..."
	echo "Options:"
	echo "  -c | --copy: do not overwrite srt files, create new"
	echo "  -d | --dry-run: just checks for tags"
	echo "  -h | --help: display help"
}

## Parse args
ENDLOOP=false
while [ "$ENDLOOP" = "false" ]; do
	case "$1" in
	"-c"|"--copy")
		MODE="COPY"
		 shift ;;
	"-d"|"--dry-run")
		MODE="DRYRUN"
		shift ;;
	"-h"|"--help")
		__usage
		exit 0 ;;
	"-"*)
		__usage
		exit 1 ;;
	*)
		ENDLOOP="true" ;;
	esac
done


## Main loop
for FILE in "$@"; do 
	if [ -d "$FILE" ]; then
		__processFolder "$FILE"
	else
		__testFile "$FILE" && __removeTagsFromFile "$FILE"
	fi
done
