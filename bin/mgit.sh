#!/bin/bash

MGIT_PAGER="less -R"
MGIT_CONF="./mgit.conf"
MGIT_LIST="conf"

GIT="/usr/bin/git"

NORMAL="\e[0m" 
GREEN="\e[1;32m" 
RED="\e[1;31m" 
PINK="\e[1;35m" 
BLUE="\e[1;34m"
WHITE="\e[0;02m" 
YELLOW="\e[1;33m" 
CYAN="\e[1;36m"

function fillLine() {
	ITEM="$1"
	if test -z "$ITEM"; then
		echo ""
	else
		WIDTH=`tput cols` 
		ITEMLEN=`printf "$ITEM" | wc -m`
		if test $ITEMLEN -gt $WIDTH; then 
			printf "$ITEM\n"
		else 
			COUNT=$(($WIDTH / $ITEMLEN))
			for I in `seq 1 $COUNT`; do
				printf "$ITEM"
			done
			printf "\n"
		fi
	fi
}

function main () {
	if test "$MGIT_LIST" = "conf" && test -f "$MGIT_CONF"; then
		LIST=`cat "$MGIT_CONF"`
	else
		LIST=`find -L . -name ".git" -type d -exec dirname {} \; | sort`
	fi 
	for PROJECT_FOLDER in $LIST; do 
		if test -d "$PROJECT_FOLDER"; then
			(cd "$PROJECT_FOLDER"
				PROJECT_NAME=`basename "$PROJECT_FOLDER"`
				BRANCH=`$GIT rev-parse --abbrev-ref HEAD`
				STATUS=`$GIT status --porcelain`
				if test -z "$STATUS"; then 
					BRANCH_COLOR=$GREEN
				else 
					BRANCH_COLOR=$RED
				fi
				

				fillLine "="
				printf "$YELLOW>>>  $CYAN%s$NORMAL  $BRANCH_COLOR%s$NORMAL \n" "$PROJECT_NAME" "($BRANCH)" 
				if test $# -gt 0; then 
					echo ""
					$GIT $@ 
				fi
				fillLine "_"
			)
		fi
	done
}

while getopts "fcl" "optchar"; do
	case "$optchar" in
		l) echo "--> mode pager"; export MGIT_MODE="pager";;
		f) echo "--> using find"; export MGIT_LIST="find";;
		c) echo "--> using conf"; export MGIT_LIST="conf";;
		*) exit 1;
	esac
done
shift $((OPTIND-1)) 

if [ "$MGIT_MODE" = "pager" ]; then
	main $@ 2>&1 | $MGIT_PAGER 
else
	main $@
fi
