#!/bin/sh
# Simple script to be used on BusyBox to do tail -f on files that rotate frequently
#

export FILE="$1"

pidOfTail() {
	ps | grep "tail .*$FILE" | grep -v grep | tail -1 | awk '{print $1}'
}

getInodeOfFile() {
	stat -c %i "$FILE"
}

listenRoll() {
	sleep 1
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
tail -f -n 10 "$FILE"
while true; do 
	echo "----- Rolling file `date` -----"
	tail -f -n 1000 "$FILE"
done
