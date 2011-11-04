#!/bin/bash


RM_BIN=`which rm` || exit 1

for currentFolder in $@; do
	test -d "$currentFolder" || continue
	echo "Cleaning .DS_Store in: $currentFolder"
	find "$currentFolder" -type f -name ".DS_Store" -exec echo " rm {}" \; -exec $RM_BIN {} \;
done

