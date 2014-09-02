#!/bin/bash

if ! test `whoami` = "root"; then
	echo "This script must be ran as root"
	exit 1
fi

while test -n "$1"; do
	case "$1" in
		sd?)
			DELETE_FILE="/sys/block/$1/device/delete"
			if test -f "$DELETE_FILE"; then
				if `mount | grep -q "^/dev/$1"`; then
					echo "The drive seems to have mounted partitions, umount them before unplug"
				else
					echo "echo 1 > $DELETE_FILE in 3 seconds"
					sleep 1
					echo "echo 1 > $DELETE_FILE in 2 seconds"
					sleep 1
					echo "echo 1 > $DELETE_FILE in 1 seconds"
					sleep 1
					echo "echo 1 > $DELETE_FILE"
					echo 1 > "$DELETE_FILE"
				fi
			else
				echo "Cannot find file $DELETE_FILE"
			fi
			;;
		*)
			echo "Wrong drive $1, works on sdX only"
			;;
	esac
	shift
done

