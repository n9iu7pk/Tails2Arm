#! /bin/bash

# 2015-2016 n9iu7pk@posteo.net
# License: Free and unlimited use for everyone for ever except in case of crime
#          against Human Beeing and Human Rights.
# 20161227 n9iu7pk@posteo.net
#		   Bugfixes and more comments:
#          - CLEAN removes chroot.d/build.conf
#		   - Identification of schroots

# Perform package build inside of a schroot environment
#
# $1 	url of the package source
# $2	name of a *.dsc file
# $3 	schroot environment name
function doSchrootBuild() {
	export url="$1"
	export dscfile="$2"
	export sid="$3"
	schroot --run-session --directory=/root -c ${sid} <<EOF
if [ ! -f "${dscfile}" ]; then
echo "[\$(date +"%Y.%m.%d %H:%M:%S")] dget ${url}"
dget ${url}
else
echo "[\$(date +"%Y.%m.%d %H:%M:%S")] from local cache ${url}"
fi
echo "[\$(date +"%Y.%m.%d %H:%M:%S")] dpkg-source -x ${dscfile}"
dpkg-source -x ${dscfile}
#ls -lrt
echo "[\$(date +"%Y.%m.%d %H:%M:%S")] cd \$(for d in \$(ls -rt); do if [ -d \$d ]; then echo \$d; fi; done | tail -1)"
cd \$(for d in \$(ls -rt); do if [ -d \$d ]; then echo \$d; fi; done | tail -1)
echo "[\$(date +"%Y.%m.%d %H:%M:%S")] pwd = \$(pwd)"
if [ -f "Build" ]; then
echo "[\$(date +"%Y.%m.%d %H:%M:%S")] Build installdeps"
./Build installdeps
fi
echo "[\$(date +"%Y.%m.%d %H:%M:%S")] dpkg-buildpackage -d -aarmhf"
dpkg-buildpackage -d -aarmhf
exit \$?
EOF
	
}

# log function with date/time
#
# $1	message to log
function log() {
	echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

# Abort function with date/time
# - if error code != 0 print the message exit with error code
# - otherwise do nothing / skip
#
# $1	exit code
# $2	message to log
function abortOnFailure() {
	if [ "$1" != "" ] && [ "$1" != "0" ]; then
		echo "[$(date +"%Y-%m-%d %H:%M:%S")] ABORT($1): $2" 1>&2
		exit $1
	fi
}

# Forced installation of dependent packages
#
# $1 	url of package source
# $2	in case of 'bad'/missing packages: ASK = ask to continue; DONT_ASK = ignore
# $3	in case of existing packages: UPDATE = update; DONT_UPDATE = skip
function forceDepends() {
	url="$1"
	ask="$2"
	upd="$3"
	################################################################################
	# 2. Determine and install missing packets
	#    SOURCE !!!
	################################################################################
	log "Fehlende Pakete (apt-get install) ermitteln"
	schroot -c source:build --directory=/root -- mkdir -m 700 .gnupg
	cp /root/.gnupg/* build/root/.gnupg/
	if [ "${upd}" = "UPDATE" ]; then
		schroot -c source:build --directory=/root -- apt-get update
		schroot -c source:build --directory=/root -- apt-get -y upgrade
		schroot -c source:build --directory=/root -- apt-get -y install asciidoc lsb-release dh-autoreconf
	fi
	export BAD=""
	#for pkg in $(wget -O- "${url}" 2>/dev/null | grep "Build-Depends: " | cut -d':' -f2 | sed 's/ //g' | sed 's/)//g' | sed 's/]//g' | tr '(' '#' | tr ',' ' '); do
	dsc=$(basename ${url})
	pkg=$(basename $(dirname ${url}))
	arv=$(basename $(dirname $(dirname ${url})))
	for pkg in $(grep "Build-Depends:" "dists/${dist}/pool/main/${arv}/${pkg}/${dsc}" | cut -d':' -f2-99 | awk 'BEGIN { FS = "," } { split($0,pkg,","); for (f in pkg) {split($f, list, " "); split(list[1],word,"|"); print word[1]; }  }'); do
		pkg=$(echo $pkg | cut -d'#' -f1 | cut -d'[' -f1)
		if [ "${pkg}" != "" ]; then
			schroot -c build --directory=/root -- apt list --installed 2>&1 | grep "${pkg}" | grep -i "install" >/dev/null 2>&1
			if [ $? -ne 0 ]; then
				log "apt-get -y install ${pkg}"
				schroot -c source:build --directory=/root -- apt-get -y install ${pkg}
				abortOnFailure $? "apt-get -y install \"${pkg}\""
				if [ $? -ne 0 ]; then
					export BAD="${BAD}${pkg} "
				fi
			else
				log "Installed: ${pkg}"
			fi
		fi
	done
	if [ "${BAD}" != "" ]; then
		echo "Nicht installierte Pakete: ${BAD}" 1>&2
		if [ "$/ask}" = "ASK" ]; then
			echo "Weiter (Y/N) [Y] " 1>&2
			read c
			if [ "${c}" != "y" ] && [ "${c}" != "Y" ] && [ "${c}" != "" ]; then
				abortOnFailure 2 "Nicht installierte Pakete: ${BAD}."
			fi
		fi
	fi
}

# Forced reload packet sources
#
# $1 *.dsc URL
function forceReload() {
	url="$1"
	cwd="$(pwd)"
	dsc=$(basename ${url})
	pkg=$(basename $(dirname ${url}))
	arv=$(basename $(dirname $(dirname ${url})))
	mkdir -p -m 777 dists/${dist}/pool/main/${arv}/${pkg}
	log "************************************************************"
	log "cd \"dists/${dist}/pool/main/${arv}/${pkg}\""
	cd "dists/${dist}/pool/main/${arv}/${pkg}"
	log "dget \"${url}\""
	dget "${url}"
	cd "${cwd}"
}

################################################################################
# Usage
################################################################################
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-?" ] || [ "$1" = "--help" ]; then
	echo "usage:" 1>&2
	echo "$0 END | CLEAN | RECOVER" 1>&2
	echo "	END		End a schroot session(-force)" 1>&2
	echo "	CLEAN		End and clean up a schroot session" 1>&2
	echo "	RECOVER		recovers an oprhan schroot session" 1>&2
	echo "$0 DIST PACKAGE_SELECT SCOPE MODE" 1>&2
	echo "	DIST		*jessie* (default) or other schoot environment" 1>&2
	echo "	PACKAGE_SELECT	buildPackages.txt (default) = selected packages (from PACKAGE_BASE)" 1>&2
	echo "	SCOPE		ALL (default) = build all packages from PACKAGE_SELECT" 1>&2
	echo "			build asingle package from PACKAGE_SELECT" 1>&2
	echo "	MODE		NONE (default) = \"normal\" operation, no clean / rebuild" 1>&2
	echo "	                REBUILD = clen up prior builds, reload package and rebuild" 1>&2
	exit 1
fi

# Dev environment base is where $0 is located
cd "$(dirname "$(readlink -f "$0")")"

################################################################################
# END all schroot sessions
################################################################################
if [ "$1" = "END" ]; then
	# Find build snapshots ... 
	for s in $(ls ./btrsnap/snapshots); do
		if [ "${s:0:11}" = "build" ]; then 
			log "end session $s"
			schroot --force --end-session --directory=/root -c $s;
		fi 
	done
	exit 0
fi

################################################################################
# RECOVER all schroot sessions
################################################################################
if [ "$1" = "RECOVER" ]; then
	# Find build snapshots ... 
	for s in $(ls ./btrsnap/snapshots); do
		if [ "${s:0:11}" = "build" ]; then 
			log "recover session $s"
			schroot --force --recover-session --directory=/root -c $s;
		fi 
	done
	exit 0
fi

################################################################################
# CLEAN the "work" schroot "build"
################################################################################
if [ "$1" = "CLEAN" ]; then
	for s in $(ls ./btrsnap/snapshots/); do 
		log "end session $s"
		schroot --force --end-session --directory=/root -c $s; 
	done
	if [ -d "build" ]; then
		log "btrfs subvolume delete build"
		btrfs subvolume delete build
		log "rm -rf /etc/schroot/chroot.d/build.conf"
		rm -rf /etc/schroot/chroot.d/build.conf
	fi
	exit 0
fi

# Check, if pwd contains a directory that's named like *${dist}* 
# That indicates a schroot/btrfs volume
export dist="jessie"
export schroot="$(basename "$(find . -maxdepth 1 -type d | grep ${dist} | tail -1)")"
if [ "$1" != "" ]; then
	if (find . -maxdepth 1 -type d | grep $1 >/dev/null); then
		export dist="$1"
		export schroot="$(basename "$(find . -maxdepth 1 -type d | grep ${dist} | tail -1)")"
		shift
	fi
fi
[ "${schroot}" != "" ] && [ -d "${schroot}" ]
abortOnFailure "$?" "No schroot found for distribution '${dist}'."

# If there's a build directory, check if it is the proper debian version 
# Try to schroot and read /root/debver.txt
if [ -d "build" ]; then
	export ver=$(schroot -c build --directory=/root -- cat debver.txt)
	if [ "${schroot}" != "${ver}" ]; then
		abortOnFailure 1 "build = '${ver}'; Should be '${schroot}', please call first $0 CLEAN to build '${dist}'."
	fi
fi
log "dist = ${dist}"

# File with package URLs to build 
export PKGBUILD="buildPackages.txt"
if [ "$1" != "" ]; then
	export PKGBUILD="$1"
	shift
fi
log "PKGBUILD = ${PKGBUILD}"

# Which packages shall be build (SCOPE and PKGLIST)?
# How should they be build (MODE)
export PKGLIST=$(grep -v "#" ${PKGBUILD})
export SCOPE="ALL"
export MODE="NONE"
if [ "$1" != "" ]; then
	if [ "$1" != "ALL" ]; then
		export PKGLIST=$(grep -v "#" ${PKGBUILD} | grep $1)
		if [ "${PKGLIST}" = "" ]; then
			abortOnFailure 1 "Package '$1' not found in '${PKGBUILD}'."
		fi
	fi
	shift
	export MODE="REBUILD"
fi
if [ ${#PKGLIST} -gt 15 ]; then
	log "PKGLIST = ${PKGLIST:0:15} ..."
else
	log "PKGLIST = ${PKGLIST}"
fi
log "SCOPE = ${SCOPE}"

# Overrule how to build (MODE)
if [ "$1" != "" ]; then
	export MODE="$1"
	shift
fi
log "MODE = ${MODE}"

################################################################################
# 1. Prepare 'build' CHROOT if not present
################################################################################
if [ ! -d "build" ]; then
	log "btrfs subvolume create \"build\""
	btrfs subvolume create "build"
	abortOnFailure $? "btrfs subvolume create \"build\""
	log "rsync -a ${dist}/* build/"
	rsync -a ${schroot}/* build/
	abortOnFailure $? "rsync -a ${schroot}/* build/"
	################################################################################
	# 2a Create schroot file
	################################################################################
	cat >/etc/schroot/chroot.d/build.conf<<EOCONF
[build-sbuild]
description=Debian build (${schroot})
btrfs-source-subvolume=$(pwd)/build
type=btrfs-snapshot
btrfs-snapshot-directory=$(pwd)/btrsnap/snapshots
users=root,user
groups=root,user
root-users=root
root-groups=root
source-users=root,user
source-root-users=root
source-root-groups=root
aliases=build
profile=minimal
# uncomment the next line if you installed eatmydata in the chroot
#command-prefix=eatmydata
EOCONF
	################################################################################
	# 2b Determine missing packages and install
	#    SOURCE !!!
	################################################################################
	log "apt-get update und apt-get upgrade"
	export PKG="asciidoc lsb-release dh-autoreconf"
	schroot -c source:build --directory=/root -- apt-get update
	schroot -c source:build --directory=/root -- apt-get --force-yes -y upgrade
	log "apt-get -y install \"${PKG}\""
	schroot -c source:build --directory=/root -- apt-get --force-yes -y install ${PKG}
	abortOnFailure $? "apt-get --force-yes -y install \"${PKG}\""
	log ".gnupg kopieren"
	schroot -c source:build --directory=/root -- mkdir -m 700 .gnupg
	cp /root/.gnupg/* build/root/.gnupg/
	log "Fehlende Pakete (apt-get install) ermitteln"
	for URL in $(grep -v "#" ${PKGBUILD}); do
		log "forceReload \"${URL}\""
		forceReload "${URL}"  2>&1 | tee -a "${pkg}.log"
		log "forceDepends \"${URL}\" \"DONT_ASK\" \"DONT_UPDATE\""
		forceDepends "${URL}" "DONT_ASK" "DONT_UPDATE"  2>&1 | tee -a "${pkg}.log"
	done
fi

################################################################################
# 3. Build packet for packet - along *.dsc in SESSIONs 
################################################################################

for URL in ${PKGLIST}; do
	export dsc=$(basename ${URL})
	export pkg=$(basename $(dirname ${URL}))
	export arv=$(basename $(dirname $(dirname ${URL})))
	mkdir -p -m 777 dists/${dist}/pool/main/${arv}/${pkg}
	if [ $(ls dists/${dist}/pool/main/${arv}/${pkg}/*.deb 2>/dev/null | wc -l) -gt 0 ]; then
		log "ALREADY BUILT: ${arv}/${pkg}"
		continue
	fi
	rm -rf "${pkg}.log"
	if [ "${MODE}" = "REBUILD" ]; then
		log "forceReload \"${URL}\""
		forceReload "${URL}"  2>&1 | tee -a "${pkg}.log"
		log "forceDepends \"${URL}\" \"DONT_ASK\" \"UPDATE\""
		forceDepends "${URL}" "DONT_ASK" "UPDATE"  2>&1 | tee -a "${pkg}.log"
	fi
	export sessid=$(schroot --begin-session -c build --directory=/root) 
	log "schroot --run-session --directory=/root -c ${sessid}"
	if [ -f "dists/${dist}/pool/main/${arv}/${pkg}/${dsc}" ]; then
		cp dists/${dist}/pool/main/${arv}/${pkg}/* ./btrsnap/snapshots/${sessid}/root
		rm ./btrsnap/snapshots/${sessid}/root/*.log
		rm ./btrsnap/snapshots/${sessid}/root/*.txt
		mv ./btrsnap/snapshots/${sessid}/root/.gnupg/trustdb.gpg ./btrsnap/snapshots/${sessid}/root/.gnupg/trustedkeys.gpg

	fi

	doSchrootBuild "${URL}" "${dsc}" "${sessid}" 2>&1 | tee -a "${pkg}.log"

	cp "${pkg}.log" dists/${dist}/pool/main/${arv}/${pkg}/
	rm -rf "${pkg}.log"
	rsync -a ./btrsnap/snapshots/${sessid}/root/* dists/${dist}/pool/main/${arv}/${pkg}/
	if [ $(ls ./btrsnap/snapshots/${sessid}/root/*.deb 2>/dev/null | wc -l) -gt 0 ]; then
		log "SUCCESS: Build package '${pkg}' for '${dist}' -> dists/${dist}/pool/main/${arv}/${pkg}/$(basename ${deb})"
	else
		log "Failed to build ${pkg}, see ${pkg}.log" > "dists/${dist}/pool/main/${arv}/${pkg}/FAILED.deb"
		log "ABORT(99): Build package '${pkg}' for '${dist}'"
	fi
	log "END SESSION: schroot ${dist} ${sessid}"
	schroot --end-session -c ${sessid}
done

