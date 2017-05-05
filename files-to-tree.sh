#!/bin/bash
set -e
APP_NAME=`basename "$0"`

function __usage {
echo "NAME
	$APP_NAME - Recreate folder structure from filenames.

DESCRIPTION:
	Recreate folder structure from file with names that contains a motif.
	Only file that contains the motifs at least once will be processed.
	Files will be renamed as follow
		'FOO<MOTIF>BAR<MOTIF>NAME.jpg' --> 'FOO/BAR/NAME.jpg'

	NOTA: By default only file with jpg extension will be processed, to prevent
	      messing up with bad commands).

USAGE:
	$APP_NAME *
	$APP_NAME /path/to/filaA.jpg /path/to/filaB.jpg
	$APP_NAME -o /path/to/root/folder *
	$APP_NAME -m __@@__ *

OPTIONS:
	-h, --help
		Display this message.

	-n, --dry-run
		Only display new names, does not create any folder nor move any file.

	-l, --links
		Do not move file, use hard links instead

	-o <FOLDER>, --output=<FOLDER>
		Use given folder as root folder, default is current folder.

	-m <MOTIF>, --motif=<MOTIF>
		Use given string as separator between folder and filename.
		Default is \"$SEPARATOR_MOTIF\"

EXAMPLES:
	$APP_NAME folder${SEPARATOR_MOTIF}name.jpg
		Will rename the given file to ./folder/name.jpg
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

OUTPUT_FOLDER=""
SEPARATOR_MOTIF="_____"
OPTION_DRYRUN=false
OPTION_LINK=false

while test -n "$1"; do
	case $1 in
		-n|--dry-run)
			OPTION_DRYRUN=true ;;
		-l|--links)
			OPTION_LINK=true ;;
		-o)
			shift; OUTPUT_FOLDER="$1" ;;
		--output=?*)
			OUTPUT_FOLDER="${1#--output=}" ;;
		-m)
			shift; SEPARATOR_MOTIF="$1" ;;
		--motif=?*)
			SEPARATOR_MOTIF="${1#--motif=}" ;;
		--help|-h)
			__usage; exit 0;;
		*)	break;;
	esac
	shift
done

for SOURCE in "$@"; do
	if ! test -e "$SOURCE"; then
		echo "$SOURCE does not exist"
	else
		DESTINATION=`echo "$SOURCE" | sed "s/$SEPARATOR_MOTIF/\//g"`
		if test -n "$OUTPUT_FOLDER"; then
			mkdir -p "$OUTPUT_FOLDER"
			DESTINATION="$OUTPUT_FOLDER/$DESTINATION"
		fi
		if test -z "$DESTINATION"; then
			echo "$SOURCE: error"
		elif test "$SOURCE" = "$DESTINATION"; then
			echo "$SOURCE does not contain motif: $SEPARATOR_MOTIF"
		elif test -e "$DESTINATION"; then
			echo "$DESTINATION already exists"
		elif test $OPTION_DRYRUN = true; then
			echo "(Dry run mode) $SOURCE --> $DESTINATION"
		else
			mkdir -p "`dirname "$DESTINATION"`"
			if $OPTION_LINK = true; then
				ln -v "$SOURCE" "$DESTINATION"
			else
				mv -vn "$SOURCE" "$DESTINATION"
			fi
		fi
	fi
done
