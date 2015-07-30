#!/bin/sh
#set -e

CONF_FILE="$HOME/.mbitpocket.conf"

bitpocket help > /dev/null 2>&1

if ! test -r "$CONF_FILE"; then
	echo "Cannot find configuration file $CONF_FILE"
	exit 1
fi

test -n "$@"
echo "bitpocket command: $@"

IFS=$'\n'
for LINE in `cat "$CONF_FILE"`; do
	if test -z "$LINE"; then
		continue
	elif [[ "$LINE" = "#"* ]]; then
		continue
	elif ! test -d "$LINE"; then
		echo "Not a folder: $LINE"
	elif ! test -d "$LINE/.bitpocket"; then
		echo "Not a bitpocket folder: $LINE"
	else
		echo "$LINE --> bitpocket $@"
		(cd "$LINE" && bitpocket $@)
	fi
done 

