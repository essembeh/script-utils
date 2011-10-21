#!/bin/bash

CAT_BIN=`which cat`
RM_BIN=`which rm`
MV_BIN=`which mv`
XSLTPROC_BIN=`which xsltproc`
test -e $XSLTPROC_BIN || (echo "Cannot find xsltproc"; exit 1)

XSL_FILE=`mktemp`
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
	TMPFILE=`mktemp`
	echo "Indent $FILE (backup: $TMPFILE)"
	$MV_BIN "$FILE" "$TMPFILE"
	$XSLTPROC_BIN "$XSL_FILE" "$TMPFILE" > "$FILE" 2> /dev/null
	if [ ! $? -eq 0 ]; then
		echo "   Error with XSLTPROC, revert changes on file: $FILE"
		$MV_BIN "$TMPFILE" "$FILE"
	fi
done

$RM_BIN -f "$XSL_FILE"
