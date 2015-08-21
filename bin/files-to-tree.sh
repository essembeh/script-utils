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
	$APP_NAME /path/to/input/folder/
	$APP_NAME -a /path/to/input/folder/
	$APP_NAME -o /path/to/root/folder *
	$APP_NAME -m __@@__ *

OPTIONS:
	-h, --help
		Display this message.

  -n, --dry-run
		Only display new names, does not create any folder nor move any file.

	-a, --all
		Rename all files taht contains the motif.
		By default only files with jpg extension are processed.

	-o <FOLDER>, --output=<FOLDER>
		Use given folder as root folder, default is current folder.

	-m <MOTIF>, --motif=<MOTIF>
		Use given string as separator between folder and filename.
		Default is \"$SEPARATOR_MOTIF\"

EXAMPLES:
	$APP_NAME folder${SEPARATOR_MOTIF}name.jpg
		Will rename the given file to ./folder/name.jpg

	$APP_NAME folder${SEPARATOR_MOTIF}name.txt
		Won't do anything since not a jpg file

	$APP_NAME -a folder${SEPARATOR_MOTIF}name.txt
		Will rename the file
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

function __createFolder {
	if ! test -d "$1"; then
		if test $OPTION_DRYRUN = false; then
			mkdir -vp "$1"
		fi
	fi
}

function __moveFile {
	if $OPTION_DRYRUN = true; then
		__customOut cyan
		echo "(Dry run mode) $1 --> $2"
		__customOut reset
	else
		mv -vn "$1" "$2"
	fi
}

function __processFile {
	local FILENAME=`basename "$1"`
	## test picture
	if [ $OPTION_ALL = true ] || [[ "$FILENAME" = *.jpg ]]; then
		## Count motif
		local MOTIF_COUNT=`echo "$FILENAME" | grep -o "$SEPARATOR_MOTIF" | wc -l`
		if test $MOTIF_COUNT -ge 1; then
			local PARENT_FOLDER=`echo "$FILENAME" | sed "s/$SEPARATOR_MOTIF/\//g" | xargs -r -0 dirname`
			local REAL_FILENAME=`echo "$FILENAME" | awk -F"$SEPARATOR_MOTIF" '{print $NF}'`
			if test -n "$PARENT_FOLDER" -a -n "$REAL_FILENAME"; then
				__createFolder "$OUTPUT_FOLDER/$PARENT_FOLDER"
				__moveFile "$1" "$OUTPUT_FOLDER/$PARENT_FOLDER/$REAL_FILENAME"
			else
				__customOut red
				echo "Problem with filename $1"
				__customOut reset
			fi
		else
			__customOut yellow
			echo "Cannot find motif '$SEPARATOR_MOTIF' in $1"
			__customOut reset
		fi
	else
		__customOut blue
		echo "Bypass $1"
		__customOut reset
	fi
}

OUTPUT_FOLDER="."
SEPARATOR_MOTIF="<o_O>"
OPTION_ALL=false
OPTION_DRYRUN=false

while test -n "$1"; do
	case $1 in
		-a|--all)
			OPTION_ALL=true ;;
		-n|--dry-run)
			OPTION_DRYRUN=true ;;
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

for INPUT in "$@"; do
	if test -f "$INPUT"; then
		__processFile "$INPUT"
	elif test -d "$INPUT"; then
		find "$INPUT" -type f | while read LINE; do
			__processFile "$LINE"
		done
	fi
done
