#!/bin/bash

# Common
BASENAME_BIN=`which basename`
FIND_BIN="`which find` -mindepth 1 -maxdepth 1"
GREP_BIN=`which grep`
CAT_BIN=`which cat`
AWK_BIN=`which awk`

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
	if [ -n "$LINE" ]; then
		FILES=`echo $LINE`
		if [ ! "$FILES" = "$LINE" ]; then
			echo "$FILES" | $AWK_BIN '{print $NF}'
		fi
	fi
done
