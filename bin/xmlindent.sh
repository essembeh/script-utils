#!/bin/bash

set -e

##
## Binaries
##
CAT_BIN="$(which cat)"
RM_BIN="$(which rm)"
MV_BIN="$(which mv)"
MKTEMP_BIN="$(which mktemp)"
XSLTPROC_BIN="$(which xsltproc)"
HEAD_BIN="$(which head)"
GREP_BIN="$(which egrep)"

##
## XSL indentation file
##
XSL_FILE="$($MKTEMP_BIN)"
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

##
## Check if file is an XML file
##
__isXmlFile () {
	xmlFile="$1"
	test -f "$xmlFile" || return 1
	$HEAD_BIN -n 1 "$xmlFile" | $GREP_BIN -q "^<"
}

##
## Main
##
for CURRENT_FILE in "$@"; do
	if __isXmlFile "$CURRENT_FILE"; then
		TEMP_FILE="$($MKTEMP_BIN)"
		echo "Indent $CURRENT_FILE (backup: $TEMP_FILE)"
		$MV_BIN "$CURRENT_FILE" "$TEMP_FILE"
		$XSLTPROC_BIN "$XSL_FILE" "$TEMP_FILE" > "$CURRENT_FILE" 2> /dev/null
		if [ ! $? -eq 0 ]; then
			echo "   Error with XSLTPROC, revert changes on file: $CURRENT_FILE"
			$MV_BIN "$TEMP_FILE" "$CURRENT_FILE"
		fi
	else
		echo "*** File does not seem to be a valid XML file: $CURRENT_FILE"
	fi
done

$RM_BIN -f "$XSL_FILE"
