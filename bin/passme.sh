#!/bin/bash

function getMoreHash {
	 echo "$1" | sha1sum | awk '{print $1}' 
}

PASSMESIZE=16
PASSMEFILE=~/.passme.secret
if test -f "$PASSMEFILE"; then
	MASTER=`head -1 "$PASSMEFILE"`
else
	echo "Enter master password?"
	read MASTER
fi
HMASTER=`getMoreHash "$MASTER"`
while [[ $# > 0 ]]; do
	SEED="$1"; shift
	HSEED=`getMoreHash "$SEED"`
	HKEY=`getMoreHash "$HSEED$HMASTER"`
	echo -n "$SEED --> "
	echo "$HKEY" | base64 | head -c $PASSMESIZE
	echo 
done

