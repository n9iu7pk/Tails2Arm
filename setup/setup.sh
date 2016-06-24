#! /bin/bash

# 2015-2016 n9iu7pk@posteo.net
# License: Free and unlimited use for everyone for ever except in case of crime
#          against Human Beeing and Human Rights.

# Links/sources:
# - http://killyourtv.i2p.xyz/howtos/sbuild+btrfs+schroot/
#   Base template used for this setup. Using qemu enables you to build arm 
#   code / packages. on x86/x64 platforms. Due to an unresolved issue 
#   handling threads the tcg (qemu's tiny code generator) may crash.

# Common functions (lib)
. ./tailsDevFunc.sh

if [ "$1" == "" ] ||  [ "$1" == "-h" ] ||  [ "$1" == "--help" ] ||  [ "$1" == "-?" ]; then
	echo "" 1>&2
	echo "usage: $0 LUKS [QEMU] [DIST] [ARCH] [KMIRROR] [MIRROR]" 1>&2
	echo "LUKS	mapping device name (cryptsetup, img file and mount point)" 1>&2
	echo "QEMU	optional YES = use qemu-user-static, <other> = detect; default <other>" 1>&2
	echo "DIST	optional debian distribution, default 'jessie'" 1>&2
	echo "ARCH	optional chroot architecture, default 'arm'" 1>&2
	echo "KMIRROR	optional kernel mirror, default 'http://mirrors.kernel.org'" 1>&2
	echo "MIRROR	optional debian mirror, default 'http://ftp.debian.org'" 1>&2
	echo "" 1>&2
	echo "Must be started with root permissions!" 1>&2
	echo "" 1>&2
	exit 1
fi

# Check root permissions
[ $(id -u) -eq 0 ]
abortOnFailure "$?" "Must run with root permissions!"

export LUKSNAME="$1"

# By default a target arm environment is assumed
if [ "$(uname -m | cut -c1-3)" == "arm" ]; then
	export QEMU="NO"
else
	export QEMU="YES"
fi
case "$2" in
	"YES"|"Y"|"yes"|"y")
	 	export QEMU="YES";;
	*)	if [ "$2" != "" ]; then
	       		export QEMU="$2"
	       	fi;;
esac

export DIST="$3"
if [ "${DIST}" == "" ]; then
	export DIST="jessie"
fi

export ARCH="$4"
if [ "${ARCH}" == "" ]; then
	export ARCH="armhf"
fi
export SCHROOT="${LUKSNAME}-${DIST}-${ARCH}"

export KERNELMIRROR="$5"
if [ "${KERNELMIRROR}" == "" ]; then
	export KERNELMIRROR="http://mirrors.kernel.org"
fi

export MIRROR="$6"
if [ "${MIRROR}" == "" ]; then
	export MIRROR="http://ftp.debian.org"
fi

# Check, if an alias ${SCHROOT} already has been defined
if (grep "^aliases=${SCHROOT}$" /etc/schroot/chroot.d/* 1>/dev/null 2>&1); then
	abortOnFailure "9" "Alias '${SCHROOT}' already exists, see '/etc/schroot/chroot.d/*'."
fi
if (grep "^aliases=${SCHROOT}$" /etc/schroot/schroot.conf 1>/dev/null 2>&1); then
	abortOnFailure "9" "Alias '${SCHROOT}' already exists, see '/etc/schroot/schroot.conf'."
fi

# Check, if a qemu based chroot is required
if [ "${QEMU}" != "YES" ]; then
	[ "$(uname -m | cut -c1-3)" == "${ARCH:0:3}" ]
	abortOnFailure "$?" "ARCH = '${ARCH}' differs from platform architecture = '$(uname -m)': QEMU must be set to 'YES'."
fi

echo ""
echo "Current working directory:"
echo " $(pwd)"
echo "Use qemu:              ${QEMU}"
echo "Additional packages will be installed:"
echo " - btrfs-tools         btrfs file system"
echo " - schroot             'transactional' schroot"
echo " - sbuild              build tools"
echo " - debootstrap         required to build up chroot env's"
echo " - fakeroot            required during package build"
echo " - eatmydata           *without words*"
echo " - msetup              device mapper"
echo " - cryptsetup          cryptsetup (LUKS)"
echo " - cryptsetup-bin      cryptsetup (LUKS)"
if [ "${QEMU}" == "YES" ]; then
	echo " - qemu-user-static (installs qemu-debootstrap)"
fi
echo "schroot name:          ${SCHROOT}"
echo "Architecture (chroot): ${ARCH}"
echo "Mount point:           '${LUKSNAME}' will be created relative to cwd."
echo "schroot config file:   '/etc/schroot/chroot.d/${DIST}.conf' will be created."
echo "Kernel mirror:         ${KERNELMIRROR}"
echo "Package mirror:        ${MIRROR}"
echo ""
echo "Estimated runtime:     20-40 min."
echo ""
echo -n "Continue? (Y/N)[N]: "
read c
if [ "$c" != "y" ] &&  [ "$c" != "Y" ]; then
	exit 0
fi

#DEBUG#if [ "${DEBUG}" != "" ]; then
#DEBUG#fi

# Fix current working directory
export pwd="$(pwd)"

# Install required packages
# - btrfs-tools		btrfs file system
# - schroot		"transactional" schroot
# - sbuild		build tools
# - debootstrap		required to build up chroot env's
# - fakeroot		required during package build
# - eatmydata		*without words*
# - msetup 		device mapper
# - cryptsetup 		cryptsetup (LUKS)
# - cryptsetup-bin	cryptsetup (LUKS)
log "Install required packages"
# required to install the packages properly
apt-get -y update
abortOnFailure "$?" "apt-get update"
# BUT: *NEVER*EVER* do apt-get upgrade. 
# This must be unter control of the system owner.
apt-get -y install btrfs-tools schroot sbuild debootstrap fakeroot eatmydata dmsetup cryptsetup cryptsetup-bin
abortOnFailure "$?" "apt-get install btrfs-tools schroot sbuild debootstrap fakeroot eatmydata dmsetup cryptsetup cryptsetup-bin"
if [ "${QEMU}" == "YES" ]; then
	# If you choose a qemu emulated arm chroot, uncomment the next lines
	log "Install qemu-user-static (installs qemu-debootstrap)"
	apt-get install qemu-user-static
	abortOnFailure "$?" "apt-get install qemu-user-static"
fi 
# Create an image, file based
# - image file name
export img="${LUKSNAME}.img"
# - dd block size 
export bs="1M"
# - dd block count 
#   bs * count = size of ${img}
#   size: 1G is too small, 5G should be suitable
#         how many finally depends on what will be build and wich packets
#         are requested
export count="5120"
log "Create image file ${img}"
dd if=/dev/urandom of="${img}" bs=${bs} count=${count}
abortOnFailure "$?" "dd if=/dev/urandom of=\"${img}\" bs=${bs} count=${count}"

# Set up as loop device
log "Setup image file ${img} as loop device"
losetup -f "${img}"
abortOnFailure "$?" "losetup -f \"${img}\""
# Detect loop device name
export loopDev=$(losetup -a | grep "${img}" | cut -d':' -f1)
abortOnFailure "$?" "losetup -a | grep \"${img}\" | cut -d':' -f1"

# Crypt (LUKS) the new device ... 
# - Generate a 25 character password
export PASSWORD="$(dd if=/dev/urandom bs=25 count=1 2>/dev/null | uuencode -m %s | grep -v "^begin" | grep -v "^=" | cut -c1-25)"
log "Encrypting image ${img} using password=${PASSWORD} !!! Please change as soon as possible!!!"
# LUKS1 defaults
# - cipher: aes-xts-plain64
# - Key: 256 Bits
# - LUKS header hash: sha1
# - Random generator: /dev/urandom
cryptsetup -q luksFormat "${loopDev}" << EOCRYPT
${PASSWORD}
EOCRYPT
abortOnFailure "$?" "cryptsetup -q luksFormat \"${loopDev}\""
# ... and open/map it as ${LUKSNAME}
log "Open encrypted image ${img} as ${LUKSNAME}"
cryptsetup -q luksOpen "${loopDev}" "${LUKSNAME}" << EOCRYPT
${PASSWORD}
EOCRYPT
abortOnFailure "$?" "cryptsetup -q luksOpen \"${loopDev}\" \"${LUKSNAME}\"" 

# Format with btrfs
# - label name
export label="${LUKSNAME}"
export loopDevCrypt="/dev/mapper/${LUKSNAME}"
log "Format encrypted image ${img} with btrfs"
mkfs.btrfs --label "${label}" "${loopDevCrypt}"
abortOnFailure "$?" "mkfs.btrfs --label \"${label}\" \"${loopDevCrypt}\""

# Create a mount point and mount chroots.img
log "Mount btrfs image to"
export mountPoint="./${LUKSNAME}"
log "Create mount point ${mountPoint}"
mkdir -m 777 -p "${mountPoint}"
abortOnFailure "$?" "mkdir -m 777 -p \"${mountPoint}\""
log "Mount btrfs image into mount point ${mountPoint}"
mount "${loopDevCrypt}" "${mountPoint}"
abortOnFailure "$?" "mount \"${loopDevCrypt}\" \"${mountPoint}\""
cd "${mountPoint}"
abortOnFailure "$?" "cd \"${mountPoint}\""

# Copy build scripts
log "cp build/*.sh and *.key"
cp ../../build/*.sh .
abortOnFailure "$?" 'cp ../../build/*.sh'
cp ../../build/*.key .
abortOnFailure "$?" 'cp ../../build/*.key'

# Create subvolume for chroot system
btrfs subvolume create "${SCHROOT}"
abortOnFailure "$?" "btrfs subvolume create \"${SCHROOT}\""
mkdir -m 777 -p btrsnap/snapshots
abortOnFailure "$?" "mkdir -m 777 -p btrsnap/snapshots"

log "deboostrap debian architecture \"${ARCH}\" and distribution \"${DIST}\" from \"${KERNELMIRROR}/debian\""
debootstrap --variant=buildd --include fakeroot,eatmydata --foreign --arch "${ARCH}" "${DIST}" "${SCHROOT}" "${KERNELMIRROR}/debian"
abortOnFailure "$?" "debootstrap --variant=buildd --include fakeroot,eatmydata --foreign --arch \"${ARCH}\" \"${DIST}\" \"${SCHROOT}\" \"${KERNELMIRROR}/debian\""
if [ "${QEMU}" == "YES" ]; then
	# If a qemu emulated arm chroot was choosen
	log "cp qemu-arm-static"
	cp /usr/bin/qemu-arm-static "${SCHROOT}/usr/bin"
	abortOnFailure "$?" "cp /usr/bin/qemu-arm-static \"${SCHROOT}/usr/bin\""
fi
log "deboostrap second-stage"
chroot "${SCHROOT}" debootstrap/debootstrap --second-stage
abortOnFailure "$?" "chroot \"${SCHROOT}\" debootstrap/debootstrap --second-stage"
if [ "${QEMU}" == "YES" ]; then
	# If a qemu emulated arm chroot was choosen
	rm "${SCHROOT}/usr/bin/qemu-arm-static"
	abortOnFailure "$?" "\"${SCHROOT}/usr/bin/qemu-arm-static\""
fi

# Avoid rc runlevel actions during chroot "startup"
# Based on init; Must be reworked probabely to systemd
log "Chroot environment: Disable runlevel autostart"
cat > "${SCHROOT}/usr/sbin/policy-rc.d" << EOF
echo "All runlevel operations denied by policy" >&2
exit 101
EOF
abortOnFailure "$?" "cat > \"${SCHROOT}/usr/sbin/policy-rc.d\" << EOF"
chmod 0755 "${SCHROOT}/usr/sbin/policy-rc.d"
abortOnFailure "$?" "chmod 0755 \"${SCHROOT}/usr/sbin/policy-rc.d\""
chown root:root "${SCHROOT}/usr/sbin/policy-rc.d"
abortOnFailure "$?" "chown root:root \"${SCHROOT}/usr/sbin/policy-rc.d\""
# Avoid apt recommendations inside chroot environment
log "Avoid apt recommendations"
cat > "${SCHROOT}/etc/apt/apt.conf.d/norecs.conf" << EORC
APT::Install-Recommends "false";
EORC

# Create schroot configuration
# - requires an absolute path to schroot environment location
export distpath="$(pwd)"
# - an (optional) user which may also access the schroot enviroment
export user="user"
# - create chroot config file:
#   * chroot alias may not exist twice - unless it is defined in different
#     config files
#   * config files with the same name must be overwritten!
log "Create existing \"/etc/schroot/chroot.d/${SCHROOT}.conf\""
cat > "/etc/schroot/chroot.d/${SCHROOT}.conf" <<EOCONF
[${SCHROOT}-sbuild]
description=Debian ${SCHROOT}
btrfs-source-subvolume=${distpath}/${SCHROOT}
type=btrfs-snapshot
btrfs-snapshot-directory=${distpath}/btrsnap/snapshots
users=root,${user}
groups=root,${user}
root-users=root
root-groups=root
source-users=root,${user}
source-root-users=root
source-root-groups=root
aliases=${SCHROOT}
profile=minimal
# uncomment the next line if you installed eatmydata in the chroot
#command-prefix=eatmydata
EOCONF
abortOnFailure "$?" "cat \"/etc/schroot/chroot.d/${SCHROOT}.conf\" <<EOCONF"

# Adapt/Adjust the new chroot environment
# - install vim
log "Chroot ${SCHROOT}: apt-get install devscripts vim-tiny"
schroot -c "source:${SCHROOT}" -u root --directory=/root <<EOSCHROOT
apt-get install devscripts vim-tiny
EOSCHROOT
aborOnFailure "$?" "Chroot ${SCHROOT}: apt-get install"
# - apt mirrors
#   (No, security.debian.org does not offer https access :-( ...)
log "Chroot ${SCHROOT}: Add mirrors"
cat > "${SCHROOT}/etc/apt/sources.list" <<EOCAT
deb ${MIRROR}/debian/ ${DIST} main
deb-src ${MIRROR}/debian/ ${DIST} main
deb http://security.debian.org/ ${DIST}/updates main
deb-src http://security.debian.org/ ${DIST}/updates main
deb ${MIRROR}/debian/ ${DIST}-updates main
deb-src ${MIRROR}/debian/ ${DIST}-updates main
EOCAT
abortOnFailure "$?" "cat > \"${SCHROOT}/etc/apt/sources.list\" <<EOCAT"
# - Choose debconf frontend noninteractive and priority 1 
log "Chroot ${SCHROOT}: dpkg-reconfigure debconf --frontend=noninteractive --priority=1"
schroot -c "source:${SCHROOT}" -u root --directory=/root <<EOSCHROOT
dpkg-reconfigure debconf --frontend=noninteractive --priority=1
EOSCHROOT
abortOnFailure "$?" "Chroot ${SCHROOT}: dpkg-reconfgure debconf"
# - install packages
#   A long list of taken from a running environment.
#   It is NOT ensured to get package build working on all platforms for all
#   versions with this list. Improve it, if it fails!
log "Chroot ${SCHROOT}: apt-get install ..."
schroot -c "source:${SCHROOT}" -u root --directory=/root <<EOSCHROOT
apt-get -y update
apt-get -y upgrade
apt-get -y install man vim acl adduser adwaita-icon-theme ant ant-optional apache2-dev apt apt-transport-https apt-utils asciidoc aspell aspell-en autoconf automake autopoint autotools-dev base-files base-passwd bash binfmt-support binutils bison bsdmainutils bsdutils build-essential bzip2 ca-certificates ca-certificates-java cdbs clang clang-3.5 cmake cmake-data coreutils cpp dash dbus dbus-x11 dconf-gsettings-backend:armhf dconf-service debconf debconf-i18n debhelper debian-archive-keyring debianutils debootstrap default-jdk default-jdk-doc default-jre default-jre-headless desktop-file-utils devscripts dh-apparmor dh-autoreconf dh-python dh-systemd dictionaries-common diffstat diffutils dmsetup dpkg dpkg-dev e2fslibs:armhf e2fsprogs eatmydata ecj ecj-gcj ecj1 emacsen-common fakeroot fastjar file findutils flex fontconfig fontconfig-config fonts-dejavu-core g++ gcc gcj-jdk gcj-jre gcj-jre-headless gcj-native-helper gconf-service gconf2 gconf2-common gettext gettext-base gir1.2-atk-1.0 gir1.2-atspi-2.0 gir1.2-freedesktop:armhf gir1.2-gconf-2.0 gir1.2-gdesktopenums-3.0 gir1.2-gdkpixbuf-2.0 gir1.2-glib-2.0:armhf gir1.2-gnomekeyring-1.0 gir1.2-gtk-2.0 gir1.2-gtk-3.0:armhf gir1.2-javascriptcoregtk-3.0:armhf gir1.2-panelapplet-4.0 gir1.2-pango-1.0:armhf gir1.2-soup-2.4 gir1.2-webkit-3.0:armhf gir1.2-wnck-3.0:armhf glib-networking:armhf glib-networking-common glib-networking-services gnome-mime-data gnome-pkg-tools gnupg gpgv grep groff-base gsettings-desktop-schemas gsettings-desktop-schemas-dev gzip hardening-wrapper help2man hicolor-icon-theme hostname init init-system-helpers initscripts insserv intltool intltool-debian iso-codes java-common libacl1:armhf libantlr-java libapache-pom-java libapr1:armhf libapr1-dev libaprutil1:armhf libaprutil1-dev libapt-inst1.5:armhf libapt-pkg4.12:armhf libarchive13:armhf libart-2.0-2:armhf libart-2.0-dev libasan1:armhf libasound2:armhf libasound2-data libaspell15:armhf libasprintf0c2:armhf libasyncns0:armhf libatk-bridge2.0-0:armhf libatk-bridge2.0-dev:armhf libatk-wrapper-java libatk-wrapper-java-jni:armhf libatk1.0-0:armhf libatk1.0-data libatk1.0-dev libatomic1:armhf libatspi2.0-0:armhf libatspi2.0-dev libattr1:armhf libaudio2:armhf libaudit-common libaudit1:armhf libavahi-client-dev libavahi-client3:armhf libavahi-common-data:armhf libavahi-common-dev libavahi-common3:armhf libavahi-glib-dev libavahi-glib1:armhf libbison-dev:armhf libblkid1:armhf libbonobo2-0:armhf libbonobo2-common libbonobo2-dev:armhf libbonoboui2-0:armhf libbonoboui2-common libbonoboui2-dev:armhf libbsd0:armhf libbz2-1.0:armhf libc-bin libc-dev-bin libc6:armhf libc6-dev:armhf libcairo-gobject2:armhf libcairo-script-interpreter2:armhf libcairo2:armhf libcairo2-dev libcanberra-dev:armhf libcanberra0:armhf libcap-ng0:armhf libcap2:armhf libcap2-bin libclang-3.5-dev libclang-common-3.5-dev libclang1-3.5:armhf libclass-isa-perl libclc-dev libcloog-isl4:armhf libcolord2:armhf libcomerr2:armhf libcommons-logging-java libcommons-parent-java libcpan-meta-perl libcroco3:armhf libcryptsetup4:armhf libcups2:armhf libcurl3:armhf libcurl3-gnutls:armhf libdatrie1:armhf libdb5.3:armhf libdbus-1-3:armhf libdbus-1-dev:armhf libdbus-glib-1-2:armhf libdbus-glib-1-dev libdconf1:armhf libdebconfclient0:armhf libdevmapper1.02.1:armhf libdpkg-perl libdrm-dev:armhf libdrm-exynos1:armhf libdrm-freedreno1:armhf libdrm-nouveau2:armhf libdrm-omap1:armhf libdrm-radeon1:armhf libdrm2:armhf libeatmydata1:armhf libecj-java libecj-java-gcj libedit2:armhf libegl1-mesa:armhf libelf-dev:armhf libelf1:armhf libelfg0:armhf libenchant1c2a:armhf libencode-locale-perl libexpat1:armhf libexpat1-dev:armhf libfakeroot:armhf libffi-dev:armhf libffi6:armhf libfile-listing-perl libfl-dev:armhf libflac8:armhf libfontconfig1:armhf libfontconfig1-dev:armhf libfontenc1:armhf libfreetype6:armhf libfreetype6-dev libgail-common:armhf libgail-dev libgail18:armhf libgbm1:armhf libgcc-4.9-dev:armhf libgcc1:armhf libgcj-bc:armhf libgcj-common libgcj15:armhf libgcj15-awt:armhf libgcj15-dev:armhf libgconf-2-4:armhf libgconf2-dev libgcrypt20:armhf libgdbm3:armhf libgdk-pixbuf2.0-0:armhf libgdk-pixbuf2.0-common libgdk-pixbuf2.0-dev libgif4:armhf libgirepository-1.0-1:armhf libgl1-mesa-glx:armhf libglade2-0:armhf libglade2-dev:armhf libglapi-mesa:armhf libgles2-mesa:armhf libglib2.0-0:armhf libglib2.0-bin libglib2.0-data libglib2.0-dev libgmp-dev:armhf libgmp10:armhf libgmp3-dev libgmpxx4ldbl:armhf libgnome-2-0:armhf libgnome-keyring-common libgnome-keyring-dev libgnome-keyring0:armhf libgnome2-0:armhf libgnome2-bin libgnome2-common libgnome2-dev:armhf libgnomecanvas2-0:armhf libgnomecanvas2-common libgnomecanvas2-dev:armhf libgnomeui-0:armhf libgnomeui-common libgnomeui-dev:armhf libgnomevfs2-0:armhf libgnomevfs2-common libgnomevfs2-dev:armhf libgnutls-deb0-28:armhf libgnutls-openssl27:armhf libgnutls28-dev:armhf libgnutlsxx28:armhf libgomp1:armhf libgpg-error0:armhf libgraphite2-3:armhf libgssapi-krb5-2:armhf libgstreamer-plugins-base1.0-0:armhf libgstreamer1.0-0:armhf libgtk-3-0:armhf libgtk-3-bin libgtk-3-common libgtk-3-dev:armhf libgtk2.0-0:armhf libgtk2.0-common libgtk2.0-dev libharfbuzz-dev libharfbuzz-gobject0:armhf libharfbuzz-icu0:armhf libharfbuzz0b:armhf libhogweed2:armhf libhtml-parser-perl libhtml-tagset-perl libhtml-tree-perl libhttp-cookies-perl libhttp-date-perl libhttp-message-perl libhttp-negotiate-perl libhunspell-1.3-0:armhf libice-dev:armhf libice6:armhf libicu52:armhf libidl-dev:armhf libidl0:armhf libidn11:armhf libintl-perl libio-html-perl libio-socket-ssl-perl libisl10:armhf libjasper1:armhf libjavascriptcoregtk-3.0-0:armhf libjbig0:armhf libjpeg62-turbo:armhf libjson-c2:armhf libjson-glib-1.0-0:armhf libjson-glib-1.0-common libk5crypto3:armhf libkeyutils1:armhf libkmod2:armhf libkrb5-3:armhf libkrb5support0:armhf liblcms2-2:armhf libldap-2.4-2:armhf libldap2-dev:armhf libllvm3.5:armhf liblocale-gettext-perl libltdl7:armhf liblua5.1-0:armhf liblwp-mediatypes-perl liblwp-protocol-https-perl liblzma5:armhf liblzo2-2:armhf libmagic1:armhf libmhash2:armhf libmng1:armhf libmodule-build-perl libmount1:armhf libmpc3:armhf libmpdec2:armhf libmpfr4:armhf libncurses5:armhf libncursesw5:armhf libnet-http-perl libnet-ssleay-perl libnettle4:armhf libnspr4:armhf libnss3:armhf libobjc-4.9-dev:armhf libobjc4:armhf libogg0:armhf liborbit-2-0:armhf liborbit2:armhf liborbit2-dev liborc-0.4-0:armhf libp11-kit-dev libp11-kit0:armhf libpam-modules:armhf libpam-modules-bin libpam-runtime libpam0g:armhf libpanel-applet-4-0 libpanel-applet-4-dev libpango-1.0-0:armhf libpango1.0-dev libpangocairo-1.0-0:armhf libpangoft2-1.0-0:armhf libpangoxft-1.0-0:armhf libpath-class-perl libpcre3:armhf libpcre3-dev:armhf libpcrecpp0:armhf libpcsclite1:armhf libpipeline1:armhf libpixman-1-0:armhf libpixman-1-dev libpng12-0:armhf libpng12-dev:armhf libpopt-dev:armhf libpopt0:armhf libprocps3:armhf libproxy1:armhf libpsl0:armhf libpthread-stubs0-dev:armhf libpulse0:armhf libpython-stdlib:armhf libpython2.7-minimal:armhf libpython2.7-stdlib:armhf libpython3-stdlib:armhf libpython3.4-minimal:armhf libpython3.4-stdlib:armhf libqt4-dbus:armhf libqt4-declarative:armhf libqt4-designer:armhf libqt4-dev libqt4-dev-bin libqt4-help:armhf libqt4-network:armhf libqt4-qt3support:armhf libqt4-script:armhf libqt4-scripttools:armhf libqt4-sql:armhf libqt4-svg:armhf libqt4-test:armhf libqt4-xml:armhf libqt4-xmlpatterns:armhf libqtcore4:armhf libqtdbus4:armhf libqtgui4:armhf libraptor2-0:armhf librasqal3:armhf librdf0:armhf libreadline6:armhf librest-0.7-0:armhf librsvg2-2:armhf librsvg2-common:armhf librtmp1:armhf libsasl2-2:armhf libsasl2-modules-db:armhf libsctp-dev libsctp1:armhf libsecret-1-0:armhf libsecret-common libselinux1:armhf libselinux1-dev:armhf libsemanage-common libsemanage1:armhf libsepol1:armhf libsepol1-dev:armhf libservice-wrapper-java libsigsegv2:armhf libslang2:armhf libsm-dev:armhf libsm6:armhf libsmartcols1:armhf libsndfile1:armhf libsoup-gnome2.4-1:armhf libsoup2.4-1:armhf libsqlite3-0:armhf libss2:armhf libssh2-1:armhf libssl-dev:armhf libssl1.0.0:armhf libstartup-notification0:armhf libstartup-notification0-dev:armhf libstdc++-4.9-dev:armhf libstdc++6:armhf libswitch-perl libsystemd0:armhf libtasn1-6:armhf libtasn1-6-dev libtdb1:armhf libtext-charwidth-perl libtext-iconv-perl libtext-unidecode-perl libtext-wrapi18n-perl libthai-data libthai0:armhf libtiff5:armhf libtimedate-perl libtinfo-dev:armhf libtinfo5:armhf libtool libubsan0:armhf libudev-dev:armhf libudev1:armhf libunistring0:armhf liburi-perl libusb-0.1-4:armhf libustr-1.0-1:armhf libuuid1:armhf libvdpau-dev:armhf libvdpau1:armhf libvorbis0a:armhf libvorbisenc2:armhf libvorbisfile3:armhf libwayland-client0:armhf libwayland-cursor0:armhf libwayland-dev libwayland-server0:armhf libwebkitgtk-3.0-0:armhf libwebkitgtk-3.0-common libwebp5:armhf libwnck-3-0:armhf libwnck-3-common libwnck-3-dev libwrap0:armhf libwww-perl libwww-robotrules-perl libx11-6:armhf libx11-data libx11-dev:armhf libx11-xcb-dev:armhf libx11-xcb1:armhf libxau-dev:armhf libxau6:armhf libxaw7:armhf libxcb-dri2-0:armhf libxcb-dri2-0-dev:armhf libxcb-dri3-0:armhf libxcb-dri3-dev:armhf libxcb-glx0:armhf libxcb-glx0-dev:armhf libxcb-present-dev:armhf libxcb-present0:armhf libxcb-randr0:armhf libxcb-randr0-dev:armhf libxcb-render0:armhf libxcb-render0-dev:armhf libxcb-shape0:armhf libxcb-shape0-dev:armhf libxcb-shm0:armhf libxcb-shm0-dev:armhf libxcb-sync-dev:armhf libxcb-sync1:armhf libxcb-util0:armhf libxcb-xfixes0:armhf libxcb-xfixes0-dev:armhf libxcb1:armhf libxcb1-dev:armhf libxcomposite-dev libxcomposite1:armhf libxcursor-dev:armhf libxcursor1:armhf libxdamage-dev:armhf libxdamage1:armhf libxdmcp-dev:armhf libxdmcp6:armhf libxext-dev:armhf libxext6:armhf libxfixes-dev:armhf libxfixes3:armhf libxfont1:armhf libxft-dev libxft2:armhf libxi-dev libxi6:armhf libxinerama-dev:armhf libxinerama1:armhf libxkbcommon-dev libxkbcommon0:armhf libxkbfile1:armhf libxml-libxml-perl libxml-namespacesupport-perl libxml-parser-perl libxml-sax-base-perl libxml-sax-perl libxml2:armhf libxml2-dev:armhf libxml2-utils libxmu6:armhf libxmuu1:armhf libxpm4:armhf libxrandr-dev:armhf libxrandr2:armhf libxrender-dev:armhf libxrender1:armhf libxres-dev libxres1:armhf libxshmfence-dev:armhf libxshmfence1:armhf libxslt1.1:armhf libxt6:armhf libxtst-dev:armhf libxtst6:armhf libxxf86vm-dev:armhf libxxf86vm1:armhf libyajl2:armhf libyaml-0-2:armhf linux-libc-dev:armhf llvm-3.5 llvm-3.5-dev llvm-3.5-runtime locales login lsb-base lsb-release m4 make man-db mawk mime-support mount mozilla-devscripts multiarch-support ncurses-base ncurses-bin netbase nettle-dev openjdk-7-doc openjdk-7-jdk:armhf openjdk-7-jre:armhf openjdk-7-jre-headless:armhf openssl orbit2 pandoc pandoc-data passwd patch pbuilder perl perl-base perl-modules pkg-config po-debconf procps psmisc python python-distutils-extra python-librdf python-minimal python2.7 python2.7-minimal python3 python3-all python3-distutils-extra python3-gi python3-gnupg python3-minimal python3.4 python3.4-minimal qdbus qt4-linguist-tools qt4-qmake qtchooser qtcore4-l10n quilt readline-common sed sensible-utils shared-mime-info startpar systemd systemd-sysv sysv-rc sysvinit sysvinit-utils tar texinfo txt2tags tzdata tzdata-java ucf udev unzip util-linux uuid-dev:armhf vim-common vim-tiny wget x11-common x11-xkb-utils x11proto-composite-dev x11proto-core-dev x11proto-damage-dev x11proto-dri2-dev x11proto-dri3-dev x11proto-fixes-dev x11proto-gl-dev x11proto-input-dev x11proto-kb-dev x11proto-present-dev x11proto-randr-dev x11proto-record-dev x11proto-render-dev x11proto-resource-dev x11proto-xext-dev x11proto-xf86vidmode-dev x11proto-xinerama-dev xauth xkb-data xorg-sgml-doctools xserver-common xtrans-dev xvfb xz-utils zip zlib1g:armhf zlib1g-dev:armhf
EOSCHROOT
abortOnFailure "$?" "Chroot ${SCHROOT}: apg-get install"
# - Create debian version info 
log "Chroot ${SCHROOT}: create debian version info root/debver.txt"
echo "${SCHROOT}" > "${SCHROOT}/root/debver.txt"
abortOnFailure "$?" "Chroot ${SCHROOT}: echo \"${SCHROOT}\" > \"${SCHROOT}/root/debver.txt\""

# Unmount and clean up
cd "${pwd}"
umountDev "${img}" "${LUKSNAME}"
abortOnFailure "$?" "unmountDev \"${img}\" \"${LUKSNAME}\""

echo ""
echo "Tails package build environment created:"
echo " - image file  ${img}"
echo " - mount point ${LUKSNAME}"
echo " - passord     ${PASSWORD} !!!Change as soon as possible, see man cryptsetup!!!"
echo " - schroot     ${SCHROOT}"
echo ""
echo "To mount execute from '$(pwd)':"
echo "   mount.sh \"${LUKSNAME}\""
echo ""
echo "To access the build environment (non-transactional):"
echo "   schroot -c \"source:${SCHROOT}\" -u root --directory=/root"
echo ""
echo "To access the build environment (transactional):"
echo "   schroot -c \"${SCHROOT}\" -u root --directory=/root"
echo ""
echo "To unmount execute from '$(pwd)':"
echo "   umount.sh \"${LUKSNAME}\""
echo ""
echo "Enjoy :)"



