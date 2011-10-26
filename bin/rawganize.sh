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
	for currentFile in "$@"; do
		if [ "$SECURE_DELETE" = "true" ]; then
			echo "$INDENT2 rm -i $currentFile"
			__dryrun && mkdir -p "$TRASH_FOLDER" > /dev/null 2>&1
			__dryrun && mv "$currentFile" "$TRASH_FOLDER/"
		else
			echo "$INDENT2 rm $currentFile"
			__dryrun && rm -f "$currentFile"
		fi
	done
}

__findFilesByExtensions () {
	folder="$1"; shift
	listOfExtensions="$@"
	for currentExtension in $listOfExtensions; do
		find "$folder" -type f -mindepth 1 -maxdepth 1 -iname *.$currentExtension 2> /dev/null
	done
}

__countFilesInDir ()  {
	folder="$1"; shift
	listOfExtensions="$@"
	count=`__findFilesByExtensions "$folder" "$listOfExtensions" | wc -l`
	return $count
}

__findCorrespondingRaw () {
	jpgFile="$1"
	rawFolder="$2"
	jpgBasename=$(basename "$jpgFile")
	for currentRawExtension in $EXTENSIONS_RAW; do 
		rawBasename=$(echo "$jpgBasename" | sed -r "s/\.[[:alnum:]]+$/.$currentRawExtension/")
		rawFile="$rawFolder/$rawBasename"
		test -f "$rawFile" && return 0
	done
	return 1
}

__isPhotoFolder () {
	folder="$1"
	test -d "$folder" || return 1
	__countFilesInDir "$folder" "$EXTENSIONS_JPG" "$EXTENSIONS_RAW" && return 2
	return 0
} 

__moveJpgToSubfolder () {
	sourceFolder="$1"
	destinationFolder="$2"
	__findFilesByExtensions "$sourceFolder" "$EXTENSIONS_JPG" | while read currentJpgFile; do
		if __findCorrespondingRaw "$currentJpgFile" "$sourceFolder"; then
			echo "$INDENT2 mv $currentJpgFile"
			__dryrun && mkdir -p "$destinationFolder"
			__dryrun && mv "$currentJpgFile" "$destinationFolder"
		fi
	done
}

__moveClipsToSubfolder () {
	sourceFolder="$1"
	destinationFolder="$2"
	__findFilesByExtensions "$sourceFolder" "$EXTENSIONS_VID" | while read currentClip; do
		echo "$INDENT2 mv $currentClip"
		__dryrun && mkdir -p "$destinationFolder"
		__dryrun && mv "$currentClip" "$destinationFolder"
	done
}

__syncRawAndJpg () {
	rawFolder="$1"
	jpgFolder="$2"
	# check if directories exist
	test -d "$rawFolder" || return 1
	test -d "$jpgFolder" || return 2
	# For each jpg, if the RAW does not exist, delete the jpg
	__findFilesByExtensions "$jpgFolder" "$EXTENSIONS_JPG" | while read currentJpgFile; do
		__findCorrespondingRaw "$jpgFolder" "$rawFolder" || __removeFile "$currentJpgFile"
	done
}

__cleanFolder () {
	rawFolder="$1"
	__findFilesByExtensions "$rawFolder" "$EXTENSIONS_DELETE" | while read currentFile; do
		__removeFile "$currentFile"
	done
}

if [ "$1" = "--dry-run" ]; then
	echo "*** dry run mode ***"
	DRYRUN="true"
	shift
fi

for currentFolder in "$@"; do
	# Check if folder is a photo folder
	if __isPhotoFolder "$currentFolder"; then
		echo "Processing folder: $currentFolder"
		# if it contains RAW AND JPG, so make a subfolder for JPG
		echo "$INDENT1 Sync RAW+JPG"
		__moveJpgToSubfolder "$currentFolder" "$currentFolder/$SUBFOLDER_JPG"
		__syncRawAndJpg "$currentFolder" "$currentFolder/$SUBFOLDER_JPG"

		# if it contains clips, so make a subfolder for clips
		echo "$INDENT1 Moving clips"
		__moveClipsToSubfolder "$currentFolder" "$currentFolder/$SUBFOLDER_VID"

		# clean
		echo "$INDENT1 Clean"
		__cleanFolder "$currentFolder"
	else
		echo "Error, Folder: $currentFolder, is not a photo folder"
	fi
	echo ""
done

