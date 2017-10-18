#!/bin/sh
set -e

DEFAULT_FILE="$HOME/.wallpaper.xml"
DURATION=60
TRANSITION=1
FIST_IMAGE=""
PREVIOUS_IMAGE=""
OPTION_SET=false

__usage () {
echo "NAME
	gnome-dynamic-wallpaper - Tool to create a dynamic wallpaper for gnome3

USAGE
	gnome-dynamic-wallpaper 01.JPG 02.JPG 03.jpg 
	gnome-dynamic-wallpaper 01.JPG 02.JPG 03.jpg > ~/.wallpaper.xml
	gnome-dynamic-wallpaper -s *.jpg
	gnome-dynamic-wallpaper -d 60 -t 5 -s *.jpg

OPTIONS
	-h, --help
		Diplay this message.

	-d N
		Set image duration in sec, default 60
	
	-t N
		Set transition duration in sec, default 1

	-s
		Writes output to $DEFAULT_FILE and use gsettings to use it.
	
"
}
while test -n "$1"; do
	case $1 in 
		-s) OPTION_SET=true ;;
		-d) shift; DURATION="$1";;
		-t) shift; TRANSITION="$1";;
		-h|--help) __usage; exit 0;;
		*) break;;
	esac
	shift
done
test "$OPTION_SET" = "false" || exec > "$DEFAULT_FILE"
echo "<background>"
echo "  <starttime><hour>0</hour><minute>00</minute><second>00</second></starttime>"
for IMAGE in "$@"; do
	CURRENT_IMAGE=$(realpath "$IMAGE")
	test -f "$CURRENT_IMAGE"
	test -n "$FIST_IMAGE" || FIST_IMAGE="$CURRENT_IMAGE"
	if [ -n "$PREVIOUS_IMAGE" ]; then
		echo "  <transition><duration>$TRANSITION</duration><from>$PREVIOUS_IMAGE</from><to>$CURRENT_IMAGE</to></transition>"
	fi
	echo "  <static><duration>$DURATION</duration><file>$CURRENT_IMAGE</file></static>"
	PREVIOUS_IMAGE="$CURRENT_IMAGE"
done
if [ -n "$FIST_IMAGE" -a -n "$PREVIOUS_IMAGE" ]; then
	echo "  <transition><duration>$TRANSITION</duration><from>$PREVIOUS_IMAGE</from><to>$FIST_IMAGE</to></transition>"
fi
echo "</background>"

test "$OPTION_SET" = "false" || gsettings set org.gnome.desktop.background picture-uri "file://$DEFAULT_FILE"
