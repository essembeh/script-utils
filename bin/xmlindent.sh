#!/bin/bash

CAT_BIN=`which cat` || exit 1
RM_BIN=`which rm` || exit 1
MV_BIN=`which mv` || exit 1
MKTEMP_BIN=`which mktemp` || exit 1
XSLTPROC_BIN=`which xsltproc` || exit 1

XSL_FILE=`$MKTEMP_BIN` || exit 2
$CAT_BIN << EOF > $XSL_FILE
<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	<xsl:output method="xml" indent="yes"/>
	<xsl:strip-space elements="*"/>
	<xsl:template match="/">
		<xsl:copy-of select="."/>
	</xsl:template>
</xsl:stylesheet>
EOF

for FILE in "$@"; do
	TMPFILE=`$MKTEMP_BIN` || exit 3
	echo "Indent $FILE (backup: $TMPFILE)"
	$MV_BIN "$FILE" "$TMPFILE"
	$XSLTPROC_BIN "$XSL_FILE" "$TMPFILE" > "$FILE" 2> /dev/null
	if [ ! $? -eq 0 ]; then
		echo "   Error with XSLTPROC, revert changes on file: $FILE"
		$MV_BIN "$TMPFILE" "$FILE"
	fi
done

$RM_BIN -f "$XSL_FILE"
