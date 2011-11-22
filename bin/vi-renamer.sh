#!/bin/bash
##
## Functions
##
__printLine () {
	__print "$1" "$2"
	echo 
}
__print () {
	printf "%10s %s" "[$1]" "$2"
}
__error () {
	__printLine error "$1"
	exit 1
}
__getLine () {
	$sed -n ${2}p < "$1"
}
##
## Binaries
##
awk=`which awk` || __error "Error finding command: awk"
sed=`which sed` || __error "Error finding command: sed"
basename=`which basename` || __error "Error finding command: basename"
dirname=`which dirname` || __error "Error finding command: dirname"
mktemp=`which mktemp` || __error "Error finding command: mktemp"
seq=`which seq` || __error "Error finding command: seq"
mv=`which mv` || __error "Error finding command: mv"
wc=`which wc` || __error "Error finding command: wc"
##
## Main
##
test $# -eq 0 && __error "Usage: $0 <FILE> <FILE> ..."
test -z "$EDITOR" && export EDITOR=vim
tmpFileA=`$mktemp` || __error "Error with mktemp"
tmpFileB=`$mktemp` || __error "Error with mktemp"
for currentArg in "$@"; do 
	if test -e "$currentArg"; then
		echo "$currentArg" >> "$tmpFileA"
		echo "$currentArg" >> "$tmpFileB"
	fi
done
$EDITOR "$tmpFileB" 
lineCountA=$($wc -l "$tmpFileA" | $awk '{print $1}')
lineCountB=$($wc -l "$tmpFileB" | $awk '{print $1}')
test $lineCountA -eq $lineCountB || __error "Line count does not match"
for index in `$seq 1 $lineCountA`; do 
	currentFileA="`__getLine "$tmpFileA" $index`"
	currentFileB="`__getLine "$tmpFileB" $index`"
	## Check path
	dirnameA=`$dirname "$currentFileA"`
	dirnameB=`$dirname "$currentFileB"`
	if [ ! "$dirnameA" = "$dirnameB" ]; then
		__printLine error "Different dirnames, do nothing for file: $currentFileA"
	else
		basenameA=`$basename "$currentFileA"`
		basenameB=`$basename "$currentFileB"`
		if [ ! "$basenameA" = "$basenameB" ]; then
			__print info ""
			$mv -v "$currentFileA" "$currentFileB"
		fi
	fi
done

