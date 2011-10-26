#!/bin/bash

##
## Binaries
##
CAT_BIN=`which cat` || exit 1
RM_BIN=`which rm` || exit 1
MV_BIN=`which mv` || exit 1
MKTEMP_BIN=`which mktemp` || exit 1
XSLTPROC_BIN=`which xsltproc` || exit 1
HEAD_BIN=`which head` || exit 1
GREP_BIN=`which egrep` || exit 1

##
## XSL indentation file
##
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
for currentFile in "$@"; do
	if __isXmlFile "$currentFile"; then
		tmpFile=`$MKTEMP_BIN` || exit 3
		echo "Indent $currentFile (backup: $tmpFile)"
		$MV_BIN "$currentFile" "$tmpFile"
		$XSLTPROC_BIN "$XSL_FILE" "$tmpFile" > "$currentFile" 2> /dev/null
		if [ ! $? -eq 0 ]; then
			echo "   Error with XSLTPROC, revert changes on file: $currentFile"
			$MV_BIN "$tmpFile" "$currentFile"
		fi
	else
		echo "*** File does not seem to be a valid XML file: $currentFile"
	fi
done

$RM_BIN -f "$XSL_FILE"
