#! /bin/bash

# 2015-2016 n9iu7pk@posteo.net
# License: Free and unlimited use for everyone for ever except in case of crime
#          against Human Beeing and Human Rights.

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-?" ] || [ "$1" = "--help" ]; then
	echo "usage: $0 SERVER" 1>&2
	echo "SERVER	tails package repository, usually deb.tails.boum.org" 1>&2
	exit 1
fi

# Should be something similar to deb.tails.boum.org
export SERVER="$1"
ping -c 1 -W 1 "${SERVER}" 2>/dev/null 1>&2
if [ $? -ne 0 ]; then
	echo "ABORT(1): Server '${SERVER}' not reacheable (by ping)."
	exit 1
fi

# Package and source location
export URL="http://${SERVER}/pool/main/"
# Sources is a file. It contains descriptions/definitions of all tails specific
# packages.
export SRC="http://${SERVER}/dists/devel/main/source/Sources"
# Download into /tmp
wget -O- ${SRC} >/tmp/Sources 2>/dev/null
# Extract package names ... except themes: They aren't supported yet.
export TAILS="$(grep "^Package:" /tmp/Sources | grep -v theme | cut -d' ' -f2)"
# Number of lines in Sources ...
export LEN=$(cat /tmp/Sources | wc -l)
# Iterate over *positions* (line numbers)!
for pos in $(grep -n "^Package: " /tmp/Sources | cut -d':' -f1); do
	# pos now contains the line number inside of Sources in which 
	# the package definition starts
	export tpos=$(($LEN - $pos + 1))
	# Get package name ... 
	export PKG=$(tail -${tpos} /tmp/Sources | grep -m1 "^Package: " | cut -d' ' -f2)
	# Get packages first character. This is a part of the path of the 
 	# package and source location
	export A=${PKG:0:1}
	# Iterate over requred package *.dsc files 
	for f in $(tail -${tpos} /tmp/Sources | grep -m1 -A4 "^Files:" | grep "^ " | grep ".dsc" | cut -d' ' -f4 | sort -u); do
		echo "${TAILS}" | grep "${PKG}" >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "${URL}${A}/${PKG}/${f}"
		else
			echo "#${URL}${A}/${PKG}/${f}"
		fi
	done
done

