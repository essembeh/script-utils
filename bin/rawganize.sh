#/bin/bash

INDENT1="|-----"
INDENT2="|      |-----"
SECURE_DELETE="true"
TRASH_FOLDER="$HOME/.Trash"
DRYRUN="false"

SUBFOLDER_JPG="raw+jpg"
SUBFOLDER_VID="clips"
EXTENSIONS_VID="mpg mpeg avi mp4 mov"
EXTENSIONS_RAW="cr2 nef"
EXTENSIONS_JPG="jpg jpeg"
EXTENSIONS_DELETE="thm"


__dryrun () {
	test "$DRYRUN" = "true" && return 1
	return 0
}

__removeFile () {
	for FILE in "$@"; do
		if [ "$SECURE_DELETE" = "true" ]; then
			echo "$INDENT2 rm -i $FILE"
			__dryrun && mkdir -p "$TRASH_FOLDER" > /dev/null 2>&1
			__dryrun && mv "$FILE" "$TRASH_FOLDER/"
		else
			echo "$INDENT2 rm $FILE"
			__dryrun && rm -f "$FILE"
		fi
	done
}

__findFilesByExtensions () {
	FOLDER="$1"; shift
	ALL_PATTERNS="$@"
	for CURRENT_PATTERN in $ALL_PATTERNS; do
		find "$FOLDER" -type f -mindepth 1 -maxdepth 1 -iname *.$CURRENT_PATTERN 2> /dev/null
	done
}

__countFilesInDir ()  {
	FOLDER="$1"; shift
	EXTENSIONS="$@"
	TOTAL_COUNT=`__findFilesByExtensions "$FOLDER" "$EXTENSIONS" | wc -l`
	return $TOTAL_COUNT
}

__findCorrespondingRaw () {
	JPG_FILE="$1"
	RAW_FOLDER="$2"
	JPG_BASENAME=$(basename "$JPG_FILE")
	for RAW_EXTENSION in $EXTENSIONS_RAW; do 
		RAW_BASENAME=$(echo "$JPG_BASENAME" | sed -E "s/\.[[:alnum:]]+$/.$RAW_EXTENSION/")
		RAW_FILE="$RAW_FOLDER/$RAW_BASENAME"
		test -f "$RAW_FILE" && return 0
	done
	return 1
}

__isPhotoFolder () {
	FOLDER="$1"
	test -d "$FOLDER" || return 1
	__countFilesInDir "$FOLDER" "$EXTENSIONS_JPG" "$EXTENSIONS_RAW" && return 2
	return 0
} 

	
	
__moveJpgToSubfolder () {
	SOURCE_FOLDER="$1"
	DESTINATION_FOLDER="$2"
	__findFilesByExtensions "$SOURCE_FOLDER" "$EXTENSIONS_JPG" | while read CURRENT_JPG; do
		if __findCorrespondingRaw "$CURRENT_JPG" "$SOURCE_FOLDER"; then
			echo "$INDENT2 mv $CURRENT_JPG"
			__dryrun && mkdir -p "$DESTINATION_FOLDER"
			__dryrun && mv "$CURRENT_JPG" "$DESTINATION_FOLDER"
		fi
	done
}

__moveClipsToSubfolder () {
	SOURCE_FOLDER="$1"
	DESTINATION_FOLDER="$2"
	__findFilesByExtensions "$SOURCE_FOLDER" "$EXTENSIONS_VID" | while read CURRENT_VID; do
		echo "$INDENT2 mv $CURRENT_VID"
		__dryrun && mkdir -p "$DESTINATION_FOLDER"
		__dryrun && mv "$CURRENT_VID" "$DESTINATION_FOLDER"
	done
}

__syncRawAndJpg () {
	RAW_FOLDER="$1"
	JPG_FOLDER="$2"

	# check if directories exist
	test -d "$RAW_FOLDER" || return 1
	test -d "$JPG_FOLDER" || return 2
	# For each jpg, if the RAW does not exist, delete the jpg
	__findFilesByExtensions "$JPG_FOLDER" "$EXTENSIONS_JPG" | while read JPG_FILE; do
		__findCorrespondingRaw "$JPG_FILE" "$RAW_FOLDER" || __removeFile "$JPG_FILE"
	done
}

__cleanFolder () {
	RAW_FOLDER="$1"
	__findFilesByExtensions "$RAW_FOLDER" "$EXTENSIONS_DELETE" | while read FILE; do
		__removeFile "$FILE"
	done
}

if [ "$1" = "--dry-run" ]; then
	echo "*** dry run mode ***"
	DRYRUN="true"
	shift
fi

for FOLDER in "$@"; do
	# Check if folder is a photo folder
	if __isPhotoFolder "$FOLDER"; then
		echo "Processing folder: $FOLDER"
		# if it contains RAW AND JPG, so make a subfolder for JPG
		echo "$INDENT1 Sync RAW+JPG"
		__moveJpgToSubfolder "$FOLDER" "$FOLDER/$SUBFOLDER_JPG"
		__syncRawAndJpg "$FOLDER" "$FOLDER/$SUBFOLDER_JPG"

		# if it contains clips, so make a subfolder for clips
		echo "$INDENT1 Moving clips"
		__moveClipsToSubfolder "$FOLDER" "$FOLDER/$SUBFOLDER_VID"

		# clean
		echo "$INDENT1 Clean"
		__cleanFolder "$FOLDER"
	else
		echo "Error, Folder: $FOLDER, is not a photo folder"
	fi
	echo ""
done

