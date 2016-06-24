#! /bin/bash

# 2015-2016 n9iu7pk@posteo.net
# License: Free and unlimited use for everyone for ever except in case of crime
#          against Human Beeing and Human Rights.

function log() {
	echo "[$(date +"%Y.%m.%d %H:%M:%S")] $1"
}

if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "-?" ] || [ "$1" = "--help" ]; then
	echo "usage: $0 PKGLIST [DIST]" 1>&2
	echo "PKGLIST	list of package (*.dsc) urls" 1>&2
	echo "DIST	(optional) target distribution (schroot environment name), default *jessie*" 1>&2
	exit 1
fi

export PKGBUILD="$1"
if [ ! -f "${PKGBUILD}" ]; then
	log "ABORT(1): Missing package file ${PKGBUILD}"
	exit 1
fi

export dist="$1"
if [ ! -d "${dist}" ]; then
	log "ABORT(1): Distribution '${dist}' not found."
	exit 1
fi

export cwd="$(pwd)"
for URL in $(grep -v "#" ${PKGBUILD}); do
	export dsc=$(basename ${URL})
	export pkg=$(basename $(dirname ${URL}))
	export arv=$(basename $(dirname $(dirname ${URL})))
	mkdir -p -m 777 dists/${dist}/pool/main/${arv}/${pkg}
	log "************************************************************"
	log "cd \"dists/${dist}/pool/main/${arv}/${pkg}\""
	cd "dists/${dist}/pool/main/${arv}/${pkg}"
	log "dget \"${URL}\""
	dget "${URL}"
	cd "${cwd}"
done
