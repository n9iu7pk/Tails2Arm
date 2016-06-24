#! /bin/bash

# 2015-2016 n9iu7pk@posteo.net
# License: Free and unlimited use for everyone for ever except in case of crime
#          against Human Beeing and Human Rights.

# Common functions (lib)
. ./tailsDevFunc.sh

if [ "$1" == "" ] ||  [ "$1" == "-h" ] ||  [ "$1" == "--help" ] ||  [ "$1" == "-?" ]; then
	echo "usage: $0 LUKS IMG" 1>&2
	echo "LUKS	mapping device name (cryptsetup)" 1>&2
	echo "IMG	(optional) name of an image file (LUKS crypted), default LUKS.img" 1>&2
	exit 1
fi
export LUKS="$1"
export IMG="$2"
if [ "${IMG}" == "" ]; then
	export IMG="${LUKS}.img"
fi

umountDev "${IMG}" "${LUKS}" "./${LUKS}"
case "$?" in
	"1") abortOnFailure "1" "Current working directory is below mount point ${LUKS}";;
	"2") abortOnFailure "2" "Umount failed";;
	"3") abortOnFailure "3" "Luks close failed";;
	"4") abortOnFailure "4" "Image file '${IMG}' does not exist";;
	"5") abortOnFailure "5" "No loop device found";;
	"6") abortOnFailure "6" "Detach loop device failed";;
esac

