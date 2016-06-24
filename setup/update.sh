#! /bin/bash

# 2015-2016 n9iu7pk@posteo.net
# License: Free and unlimited use for everyone for ever except in case of crime
#          against Human Beeing and Human Rights.

# Common functions (lib)
. ./tailsDevFunc.sh

if [ "$1" == "" ] ||  [ "$1" == "-h" ] ||  [ "$1" == "--help" ] ||  [ "$1" == "-?" ]; then
	echo "usage: $0 CHROOT" 1>&2
	echo "CHROOT	name of a chroot environment (schroot)" 1>&2
	exit 1
fi
export CHROOT="$1"

log "sbuild-update \"${CHROOT}\""
sbuild-update -udcar "${CHROOT}"
aborOnFailure "$?" "sbuild-update -udcar \"${CHROOT}\""

log "Package update/upgrade schroot \"${CHROOT}\""
schroot -c "source:${CHROOT}" -u root --directory=/root <<EOSCHROOT
apt-get -y update
apt-get -y upgrade
EOSCHROOT
aborOnFailure "$?" "schroot ${CHROOT}: apt-get update and upgrade"

log "Success"

