#!/bin/bash

PASSMESIZE=16
PASSMEFILE=~/.passme.secret
if test -f "$PASSMEFILE"; then
	PASSMASTER=`head -1 "$PASSMEFILE"`
else
	echo "Enter master password?"
	read PASSMASTER
fi

while [[ $# > 0 ]]; do
	SEED="$1"; shift
	echo -n "Computing pasword for $SEED --> "
	echo "$PASSMASTER$SEED" | sha1sum | awk '{print $1}' | base64 | head -c $PASSMESIZE
	echo 
done

