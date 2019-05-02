#!/bin/bash
set -e

BORG_ENV_FILE="BORG_ENV"
BORG_DEFAULT_ARGS="--stats --progress"

for FOLDER in "$@"; do
	echo "=============================================================================="
	test -d "$FOLDER"
	(
		cd "$FOLDER"
		NAME=$(basename "$PWD")
		echo "Backup $PWD"

		if test -r "$BORG_ENV_FILE"; then
			echo "Sourcing $PWD/$BORG_ENV_FILE"
			source "$BORG_ENV_FILE"
		else
			echo "Cannot find $PWD/$BORG_ENV_FILE"
		fi

		if test -z "$BORG_REPO"; then
			echo "BORG_REPO is not set"
			exit 1
		fi

		if test -z "$BORG_ARGS"; then
			echo "BORG_ARGS not set, using defaults: $BORG_DEFAULT_ARGS"
			BORG_ARGS="$BORG_DEFAULT_ARGS"
		else
			echo "Using custom BORG_ARGS: $BORG_ARGS"
			
		fi

		echo ""
		echo "\nListing existing snapshots for $NAME in $BORG_REPO"
		borg list -P "$NAME@"
		
		echo ""
		echo -n "Backup $PWD to $BORG_REPO ::${NAME}@{now} ? (Y/n)"
		read YN
		if test -z "$YN" -o "$YN" = "y"; then
			borg create $BORG_ARGS "::${NAME}@{now}" "."
		fi
	)
	echo ""
done

