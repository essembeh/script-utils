#!/bin/bash

CONF="./mgit.conf"
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
	if test -f "$CONF"; then
		echo "Using $CONF"
		LIST=`cat "$CONF"`
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

if [ "$1" = "-l" ]; then
	shift
	main $@ 2>&1 | less 
else
	main $@
fi
