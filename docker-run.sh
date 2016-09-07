#!/bin/bash
set -e

ARGS="-t -i"
while test -n "$1"; do
	case $1 in
		--me) ARGS="$ARGS --user $(id -u)";;
		-X) ARGS="$ARGS --volume /tmp/.X11-unix/X0:/tmp/.X11-unix/X0 --env DISPLAY=:0";;
		--mnt) ARGS="$ARGS --volume $HOME:/target/home --volume /tmp:/target/tmp --volume $PWD:/target/pwd --workdir /target/pwd";;
		--) shift; break;;
		*) break;;
	esac
	shift
done

tput setaf 7
tput setab 2
tput bold
echo "Execute: docker run $ARGS $@"
tput sgr0
docker run $ARGS $@

