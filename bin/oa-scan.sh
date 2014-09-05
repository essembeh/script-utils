#!/bin/bash

set -e

NMAP_PORTS="U:27960"

# DND when I play
ps -ef | grep -q "/usr/lib/i[o]quake3" && exit 2

# Checks
if ! test `whoami` = "root"; then
	echo "Usage: $0 [IFACE] [USER]"
	echo "    IFACE (default eth0) is the network interface to scan"
	echo "    USER (optionnal) is the user which receive the notification"
	echo 
	echo "Example: $0 eth0 seb"
	echo "         $0 eth1"
	echo "         $0"
	echo 
	echo "ATTENTION: due to nmap UDP scan, must be ran as root!!!"
	exit 3
fi
IFACE="${1-eth0}"
UI_USER="$2"

# Get IP
ADDRESS=`/sbin/ifconfig $IFACE | grep "inet ad" | awk -F: '{print $2}' | awk '{print $1}'`
test -n "$ADDRESS"

# Scan
nmap -sU -p $NMAP_PORTS $ADDRESS/24 | \
	grep -B3  "27960/udp open " | \
	grep "^Nmap scan report for " | \
	sed "s/Nmap scan report for/Openarena server running on/" | \
	while read LINE; do
		test -n "$UI_USER" && su - "$UI_USER" -c "notify-send 'Openarena' '$LINE'"
		echo $LINE
	done

