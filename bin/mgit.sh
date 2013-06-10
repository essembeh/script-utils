#!/bin/bash

MGIT_PAGER="less -R"
MGIT_CONF="./mgit.conf"
MGIT_LIST="conf"

GIT="/usr/bin/git"

NORMAL="\e[0;39m" 
VERT="\e[1;32m" 
ROUGE="\e[1;31m" 
ROSE="\e[1;35m" 
BLEU="\e[1;34m"
BLANC="\e[0;02m" 
BLANCLAIR="\e[1;08m" 
JAUNE="\e[1;33m" 
CYAN="\e[1;36m"

function main () {
	if test "$MGIT_LIST" = "conf" && test -f "$MGIT_CONF"; then
		LIST=`cat "$MGIT_CONF"`
	else
		LIST=`find -L . -name ".git" -type d | sort`
	fi 
	for GIT_FOLDER in $LIST; do 
		if test -d "$GIT_FOLDER"; then
			PROJECT_FOLDER=`dirname "$GIT_FOLDER"`
			PROJECT_NAME=`basename "$PROJECT_FOLDER"`
			BRANCH=`$GIT --git-dir="$GIT_FOLDER" --work-tree="$PROJECT_FOLDER" rev-parse --abbrev-ref HEAD`
			STATUS=`$GIT --git-dir="$GIT_FOLDER" --work-tree="$PROJECT_FOLDER" status --porcelain`
			if test -z "$STATUS"; then 
				BRANCH_COLOR=$VERT
			else 
				BRANCH_COLOR=$ROUGE
			fi
			

			echo -e "========================================================================================================="
			printf "$JAUNE>>>  $CYAN%s$NORMAL  $BRANCH_COLOR%s$NORMAL \n" "$PROJECT_NAME" "($BRANCH)" 
			if test $# -gt 0; then 
				echo ""
				$GIT --git-dir="$GIT_FOLDER" --work-tree="$PROJECT_FOLDER" $@ 
			fi
			echo -e "_________________________________________________________________________________________________________"
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
