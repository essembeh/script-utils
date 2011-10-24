#!/bin/bash


## Options
SHOW_FULLPATH="false"


# Common
BASENAME_BIN=`which basename` || exit 1
FIND_BIN="`which find` -mindepth 1 -maxdepth 1" || exit 1
GREP_BIN=`which grep` || exit 1
CAT_BIN=`which cat` || exit 1

## Functions
__expandPath () {
	PATTERN=$1
	FILES=`eval echo $PATTERN`
	for FILE in $FILES; do 
		test -f "$FILE" && echo "$FILE"
	done
}

## Retrieve CONF
if [ -z "$APP_HOME" -o ! -d "$APP_HOME" ]; then
	APP_BIN="$0"
	while [ -L "$APP_BIN" ]; do
		LINK="$(readlink "$APP_BIN")"
		if echo "$LINK" | $GREP_BIN -q "^/"; then
			APP_BIN="$LINK"
		else
			APP_BIN="$(dirname "$APP_BIN")/$LINK"
		fi  
	done
	APP_CONF="${APP_BIN%.sh}.conf"
fi

if [ ! -f "$APP_CONF" ]; then
	echo "Cannot find configuration file: $APP_CONF"
	exit 1
fi

## Main
$GREP_BIN -v "^#" "$APP_CONF" | while read LINE; do
	LAST=`__expandPath "$LINE" | tail -1`
	if [ "$SHOW_FULLPATH" = "true" ]; then
		echo "$LAST"
	else
		basename "$LAST"
	fi
done
