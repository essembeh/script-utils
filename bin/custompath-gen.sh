#!/bin/bash


CUSTOMPATH_EXPORT=".CUSTOMPATH_EXPORT"

printf "## Generated date: %s\n" "`date`"
printf "## Key file: %s\n" "$CUSTOMPATH_EXPORT"

find ~ -name "$CUSTOMPATH_EXPORT" -type f -exec dirname {} \; | while read LINE; do 
	printf "export PATH=%s:%s\n" "\$PATH" "$LINE"
done

