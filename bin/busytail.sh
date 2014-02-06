#!/bin/sh
# Simple script to be used on BusyBox to do tail -f on files that rotate frequently
#

export FILE="$1"
export ARGS="-n 100 -f $1"

pidOfTail() {
	ps | grep "tail $ARGS" | grep -v grep | tail -1 | awk '{print $1}'
}

getInodeOfFile() {
	stat -c %i "$FILE"
}

listenRoll() {
	LI=`getInodeOfFile`
	while true; do 
		PID=`pidOfTail`
		test "" = "$PID" && break
		CI=`getInodeOfFile`
		if test $CI -ne $LI; then
			kill $PID
			LI=$CI
		fi
		sleep 1
	done
}

test -e "$FILE" || exit 1

listenRoll&
while true; do 
	tail $ARGS
done
