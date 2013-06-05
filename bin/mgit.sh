#!/bin/bash

GIT=/usr/bin/git

NORMAL="\e[0;39m" 
VERT="\e[1;32m" 
ROUGE="\e[1;31m" 
ROSE="\e[1;35m" 
BLEU="\e[1;34m"
BLANC="\e[0;02m" 
BLANCLAIR="\e[1;08m" 
JAUNE="\e[1;33m" 
CYAN="\e[1;36m"


LIST=`find . -name ".git" -type d | sort`
for GIT_FOLDER in $LIST; do 
	if test -d "$GIT_FOLDER"; then
		PROJECT_FOLDER=`dirname "$GIT_FOLDER"`
		PROJECT_NAME=`basename "$PROJECT_FOLDER"`
		BRANCH=`$GIT --git-dir="$GIT_FOLDER" --work-tree="$PROJECT_FOLDER" rev-parse --abbrev-ref HEAD`

		printf "$ROUGE%s$NORMAL  $VERT%s$NORMAL \n" "$PROJECT_NAME" "($BRANCH)" 
		if test $# -gt 0; then 
			echo "      _________________________________________________________________"
			$GIT --git-dir="$GIT_FOLDER" --work-tree="$PROJECT_FOLDER" $@ 2>&1 | sed "s/^/     |  /" 
			echo "     |_________________________________________________________________"
		fi
		echo ""
	fi
done

