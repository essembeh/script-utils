#!/bin/bash

set -e

TARGET="."
test -d "$1" && TARGET="$1"
echo "Target folder: $TARGET"
find "$TARGET/" -type f -exec chmod 644 {} \;
find "$TARGET/" -type d -exec chmod 755 {} \;
find "$TARGET/" -regex ".*\.\(sh\|bin\|run\|pl\|py\|lua\)" -type f -exec chmod +x {} \;

