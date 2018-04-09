#!/bin/sh
set -e

TYPE=
NETWORK=
PASS=
HIDDEN=

echo "Type? [WEP/WPA/nopass/<empty>]"
read TYPE

echo "Network?"
read NETWORK

echo "Password?"
read PASS

echo "Hidden? [true|false]"
read HIDDEN

STRING="WIFI:"
test -n "$TYPE" && STRING="${STRING}T:${TYPE};"
test -n "$NETWORK" && STRING="${STRING}S:${NETWORK};"
test -n "$PASS" && STRING="${STRING}P:${PASS};"
test -n "$HIDDEN" && STRING="${STRING}H:${HIDDEN};"
STRING="${STRING};"

OUTPUT="$1"
test -z "$OUTPUT" && OUTPUT=`mktemp`

qrencode "$STRING" -o "$OUTPUT"
echo "QRcode generated: $OUTPUT"