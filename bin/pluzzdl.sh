#!/bin/bash

set -e

APP_DIR="$HOME/.pluzzdl"
DB_DIR="$APP_DIR/db"
CACHE_DIR="$APP_DIR/cache"
TMP_DIR="$APP_DIR/tmp"
OUTPUT_DIR="$APP_DIR/done"

JQ_BIN=

UPDATE_ZIP_URL="http://webservices.francetelevisions.fr/catchup/flux/flux_main.zip"
VIDEO_URL_PREFIX="http://medias2.francetv.fr/catchup-mobile/"
VIDEO_EXTENSION="mpg"



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

__init () {
	test -e "$APP_DIR" || mkdir -p "$APP_DIR"
	test -e "$OUTPUT_DIR" || mkdir -p "$OUTPUT_DIR"
	test -e "$CACHE_DIR" || mkdir -p "$CACHE_DIR"
	test -e "$DB_DIR" || mkdir -p "$DB_DIR"
	if which jq > /dev/null 2>&1; then
		JQ_BIN=`which jq`
	else
		JQ_BIN="$APP_DIR/lib/jq"
		if ! test -x "$JQ_BIN"; then
			__customOut reset red
			echo "Cannot find jq in PATH, download binary from http://stedolan.github.io/jq/"
			__customOut reset
			echo "Try running: "
			if uname -a | grep -q "amd64"; then
				echo " mkdir -p `dirname "$JQ_BIN"`; wget -q http://stedolan.github.io/jq/download/linux64/jq -O \"$JQ_BIN\" && chmod +x \"$JQ_BIN\""
			else 
				echo " mkdir -p `dirname "$JQ_BIN"`; wget -q http://stedolan.github.io/jq/download/linux32/jq -O \"$JQ_BIN\" && chmod +x \"$JQ_BIN\""
			fi
			exit 1
		fi
	fi
}

__clean () {
	rm -rf "$CACHE_DIR"
}

__cleanString () {
	echo "$@" | sed -E "s/[^[:alnum:]. '_-,]//g" | sed -E "s/^ *//" | sed -E "s/ *$//" | sed -E "s/ +/ /g"
}

__getKey () {
	local OUT=`echo "$1" | sed -E 's/.*"([[:alnum:]]*)": "(.*)".*/\1/'`
	if test "$2" = "true"; then
		__cleanString "$OUT"
	else
		echo "$OUT"
	fi
}

__getValue () {
	local OUT=`echo "$1" | sed -E 's/.*"([[:alnum:]]*)": "(.*)".*/\2/'`
	if test "$2" = "true"; then 
		__cleanString "$OUT"
	else
		echo "$OUT"
	fi
}

__updateZip () {
	rm -rf "$CACHE_DIR" && mkdir -p "$CACHE_DIR"
	wget -q "$UPDATE_ZIP_URL" -O "$CACHE_DIR/content.zip"
	__customOut reset purple
	unzip -d "$CACHE_DIR" "$CACHE_DIR/content.zip"
}

__log () {
	local LOGFILE="$1"; shift
	test -f "$LOGFILE"
	echo "$@" >> "$LOGFILE"
}	
	
__searchKeywords () {
	if ! test -d "$CACHE_DIR"; then 
		__customOut reset red
		echo "Cannot find json files in cache, maybe it's time for a pluzzdl.sh update ;)"
		exit 2
	fi
	for KEYWORD in "$@"; do
		"$JQ_BIN" '.programmes | map(select(.titre | contains("'"$KEYWORD"'"))) | map({id: .id_diffusion, titre1: .titre, titre2: .sous_titre, url: .url_video})' \
			"$CACHE_DIR/catch_up_"*.json
	done
}

__dump () {
    if ! test -d "$CACHE_DIR"; then
		__customOut reset red
		echo "Cannot find json files in cache, maybe it's time for a pluzzdl.sh update ;)"
		exit 2
	fi
	"$JQ_BIN" '.programmes' \
		"$CACHE_DIR/catch_up_"*.json
}

__downloadVideos () {
	local LINE
	__searchKeywords "$@" |  while read LINE; do
		if echo "$LINE" | grep -q '"id": '; then
			local ID=`__getValue "$LINE" false`
			read LINE
			local TITRE1=`__getValue "$LINE" true`
			read LINE
			local TITRE2=`__getValue "$LINE" true`
			read LINE
			local URL=`__getValue "$LINE" false`

			local FILENAME="${TITRE2:-$ID}.$VIDEO_EXTENSION"
			local TARGET_DIR="$OUTPUT_DIR/$TITRE1"
			local TARGET_VIDEO="$TARGET_DIR/$FILENAME"
			local TARGET_LOG="$TARGET_VIDEO.log"
			local TMP_VIDEO="$TMP_DIR/$ID.$VIDEO_EXTENSION"
			local TMP_LOG="$TMP_DIR/$ID.log"
			local DB_FILE="$DB_DIR/$ID"
			
			rm -rf "$TMP_DIR"
			
			if test -e "$DB_FILE"; then
				__customOut reset blue
				echo "Video already downloaded: [$ID] $TITRE1/$TITRE2"
			elif test -f "$TARGET_VIDEO"; then
				__customOut reset yellow
				echo "Video already exists: $TARGET_VIDEO"
			else
				__customOut reset cyan
				echo "Downloading video: [$ID] $TITRE1/$TITRE2"
				mkdir -p "$TMP_DIR"
				touch "$TMP_LOG" 
				__log "$TMP_LOG" "Date       : `date`"
				__log "$TMP_LOG" "id         : $ID"
				__log "$TMP_LOG" "Titre      : $TITRE1"
				__log "$TMP_LOG" "Sous-titre : $TITRE2"
				__log "$TMP_LOG" "Video URL  : $VIDEO_URL_PREFIX/$URL"
				__log "$TMP_LOG" "----- download log -----"
				
				wget -q "$VIDEO_URL_PREFIX/$URL" -O "$TMP_DIR/master.m3u"
				local SEGMENTS_URL=`cat "$TMP_DIR/master.m3u" | grep "^http://" | tail -1`
				test -n "$SEGMENTS_URL"
				wget -q "$SEGMENTS_URL" -O "$TMP_DIR/segments.list"
				local SEGMENT
				cat "$TMP_DIR/segments.list" | grep "^http://" | while read SEGMENT; do
					if wget -q "$SEGMENT" -O - >> "$TMP_VIDEO"; then
						__log "$TMP_LOG" "ok     $SEGMENT"
					else
						__log "$TMP_LOG" "error  $SEGMENT"
					fi
				done
				
				__log "$TMP_LOG" "----- end download log -----"
				
				mkdir -p "$TARGET_DIR"
				if grep -q "^error" "$TMP_LOG"; then
					__customOut reset red
					echo "    /!\\ Error downloading segments, see log: $TARGET_LOG"
					cp "$TMP_LOG" "$TARGET_LOG"
				fi
				mv "$TMP_VIDEO" "$TARGET_VIDEO"
				cp "$TMP_LOG" "$DB_FILE"
				__customOut reset green
				echo "    --> File created: $TARGET_VIDEO"
				rm -rf "$TMP_DIR"
			fi
		fi
	done
}


__init 
if test -n "$1"; then
	case "$1" in 
		"update")
			shift
			__updateZip ;;
		"search")
			shift
			__searchKeywords "$@" ;;
		"download")
			shift
			__downloadVideos "$@" ;;
		"dump")
			shift
			__dump ;;
		"clean")
			__clean ;;
		*)	exit 1;;
	esac
fi
__customOut reset

	
