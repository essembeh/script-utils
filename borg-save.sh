#!/bin/bash
set -e

BORG_ENV=".borg.env"
BORG_ARGS="--stats --progress"

for FOLDER in "$@"; do
	echo "=============================================================================="
	test -d "$FOLDER"
	(
		cd "$FOLDER"
		NAME=`basename "$PWD"`
		echo "Backup $PWD"

		if test -r "$BORG_ENV"; then
			echo "Sourcing $PWD/$BORG_ENV"
			source "$BORG_ENV"
		fi

		if test -z "$BORG_REPO"; then
			echo "BORG_REPO is not set"
			exit 1
		fi

		echo ""
		echo "Listing existing snapshots for $NAME in $BORG_REPO"
		borg list -P "$NAME@"
		
		cd ..
		test -d "$NAME"
		echo ""
		echo -n "Backup $PWD/$NAME to $BORG_REPO ::${NAME}@{now} ? (Y/n)"
		read YN
		if test -z "$YN" -o "$YN" = "y"; then
			borg create $BORG_ARGS "::${NAME}@{now}" "$NAME"
		fi
	)
	echo ""
done

