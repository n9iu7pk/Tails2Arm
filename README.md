Tools to port tails to arm
==========================
There is only one and main objective for this repository: Porting Tails to arm platforms (see https://labs.riseup.net/code/issues/10972).

This GitHub project is dedicated to contain any tools, scripts and documentations to help anybody to setup and run an arm build and an arm package build environment. This arm environment will not qualify as reproducible. All scripts and tools are a) to document and understand and b) to make it easier to set um this arm environment. Again: It is NOT intended to build up a reproducible build environment.

If you like to contribute porting tails to arm, visit https://labs.riseup.net/code/issues/10972 and https://labs.riseup.net/code/issues/11677. Current state is still a cross compiling problem see http://wiki.qemu.org/Features/tcg-multithread (also https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=769983 and http://patches.linaro.org/patch/32473/), see also below.

If you like to contribute to tails development in general, there is a description of the Tails dev and build environments (reproducible) on https://tails.boum.org/contribute/how/code/ and https://tails.boum.org/contribute/build/.

Please note: this repository shouldn't/won't never contain any Tails sources: For Tails source code please see git repositories, more informations on https://tails.boum.org.

How to set up the build debian environment? 
===========================================
Basically there are some fundamental requirements:
1) an reusable and reproducible arm build environment - reproducible in that sense: once if you've compiled and built a package your environment has been changed: Some required packages have been installed, some settings have been made and so on. Finally your environment isn't "untouced" any more, isn't any more in a defined state. So we must be able to reset our build environment back into a defined state.
2) a "multi platform" arm build platform - to build more or less generic packages, based on a quite abstract platform definition as well a general "arm" (including armeabi, armhf, armv6-X ...) or propabely also "x86_64 or ... either we do this with qemu or a crosscompiler toolchain. 

The first attemps I made, aimed to setup a crosscompiler platform. I failed due to missing arm support. Probabely this may have changed meanwhile.
Anyhow, there is a another great idea from kytv, see http://killyourtv.i2p.xyz/howtos/sbuild+btrfs+schroot/.
Due to recently got a "bad gateway" accessing his site, I'll explain his idea:
- The basic platform is based on the latest stable debian version (currently jessie).
- He's setting up a btrfs file system on a lvm volume (a lvm volume is not required, also a file image as loop device does the work).
- Then he's creating btrfs subvolumes inside of the btrfs formatted volume, a subvolume for each build environment.
- Inside of each subvolume he's creating a chroot system based on qemu.
- If all chroots have been build up, he's setting up the systems to be able to compile und build packages.
  * disable service start
  * disable installation of recommended packages
  * Install a huge list of packages (taken from a working platform; dpkg-query -list ...) - anyhow: Don't rely on it's completeness

These roughly and short noted steps are assembled in script setup.sh: 
- It should setup an environment and serve you as documentation (source = documentation).
- You must run it with root permissions: Required packages will installed.
- Feel free to adapt it to your own needs, i.e. to work without network connections (lokal/cached package repositories).
- Note: 
	* The btrfs file system on the image file is encrypted (LUKS). 
	  While encrypting a password is generated and issued, please note and change it as soon as possible (man cryptsetup).
	* The file system is currently hard coded set to 5 GB 
	  If not sufficient, feel free to change it to your own needs.

An arm specific qemu problem 
============================
If you run qemu to emulate an arm system, it's tiny code generator tcg may not work properly when running on a multi core / threaded hardware platform. For my understandig, tcg does not handle the VCPU's correctly and thus may crash when trying to assign machine code to the wrong VCPU - sometimes. 
You may pin qemu to a single core single threaded, but this won't work for i.e. java (which build i2p). Java must run multithreaded, otherwise it won't crash but won't start issuing a message. 
See:
- basically http://wiki.qemu.org/Features/tcg-multithread (thanks to LABRADOR)
- https://lists.gnu.org/archive/html/qemu-devel/2016-02/msg02651.html, 
- https://lists.gnu.org/archive/html/qemu-devel/2016-02/msg03385.html
- https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=769983 
- and "pin-single-core-fix" http://patches.linaro.org/patch/32473/

Setup build environment scripts
===============================

setup/tailsDevFunc.sh - something like a "library", common functions. Will be sourced from setup.sh, update.sh, mount.sh and umount.sh

setup.sh - set up a complete arm build environment, takes arround 20-40 min.
	Created files/structures:
		./LUKS			permanent
		./LUKS.img		permanent = 
		./LUKS/LUKS-DIST-ARCH	permanent inside LUKS.IMG 
					  schroot btrfs subvolume
		/dev/mapping/LUKS	temporal while mounted

	usage: setup.sh LUKS [QEMU] [DIST] [ARCH] [KMIRROR] [MIRROR]
	 LUKS		mapping device name (cryptsetup, img file and mount point)
			- ./LUKS.img will be the image file name (umount.sh/mount.sh)
			- LUKS will be the mapping device name when accessing the encrypted file system (umount.sh/mount.sh)
			- ./LUKS (chmod 777) will be the mout point (umount.sh/mount.sh)
	 QEMU		optional YES = use qemu-user-static, <other> = detect; default <other>
			- if you set up a chroot build environments with an architecture 
			  different from that architecture your "host" / basic system is
	  		  running, you must use qemu to emulate the platform running 
			  within chroot. Example: If you are running setup.sh on an 
	 		  intel / amd platfrom to run chroot with arm based systems you 
			  must select YES to use qemu. Otherwise if you are using a 
			  raspbery pi to run your arm chroot systems, there is no need 
			  for qemu.
	 DIST		optional debian distribution, default 'jessie'
			- wheezy shouldn't used any more. Any vaild debian version name
			  is valid.
	 ARCH		optional chroot architecture, default 'arm'
	 KMIRROR	optional kernel mirror, default 'http://mirrors.kernel.org'
	 MIRROR		optional debian mirror, default 'http://ftp.debian.org'

update.sh - update the chroot and build system 

	Does sbuild-update and apt-get update and upgrade

	usage: update.sh CHROOT
	  CHROOT	name of a chroot environment (schroot)

mount.sh - decrypt and mount your build environment
	Assume the following structure

		./LUKS			permanent
		./LUKS.img		permanent
		/dev/mapping/LUKS	temporal while mounted

	or 
		./LUKS			permanent
		./IMG 			permanent
		/dev/mapping/LUKS	temporal while mounted

	usage: mount.hs LUKS IMG
	  LUKS		mapping device name (cryptsetup) and mountpoint
	  IMG		(optional) name of an image file (LUKS crypted), default LUKS.img

umount.sh - unmount and close crypted device with your build environment
	Assume the following structure

		./LUKS			permanent
		./LUKS.img		permanent
		/dev/mapping/LUKS	temporal while mounted

	or 
		./LUKS			permanent
		./IMG 			permanent
		/dev/mapping/LUKS	temporal while mounted

	usage: umount.hs LUKS IMG
	  LUKS		mapping device name (cryptsetup) and mountpoint
	  IMG		(optional) name of an image file (LUKS crypted), default LUKS.img

Build package scripts
=====================

getPackages.sh - extract package names and urls to *.dsc files of all tails specific packages

	Investigate file http://SERVER/dists/devel/main/source/Sources and extract *.dsc urls ("^Files:" lines) for tails specific packages.
	Currently all packages except "*theme*".
	Output on stdout as list of urls.

	usage: getPackages.sh SERVER
	SERVER		tails package repository, usually deb.tails.boum.org

loadPackages.sh - load *.dsc and dget dependent ressources

	Creates
		./LUKS/dists/DIST/pool/main/P/PACKAGE 	permanent = package directory

	usage: loadPackages PKGLIST DIST
	PKGLIST	list of package (*.dsc) urls
	DIST	target distribution (schroot environment name)
		DIST must be LUKS-DIST-ARCH (as created with setups.sh)

buildPackages.sh - build packages

	Assumes
		./LUKS/DIST				permanent = DIST must be LUKS-DIST-ARCH
		./LUKS/dists/DIST/pool/main/P/PACKAGE 	permanent = package directory

	Clones a build schroot to let you debug and fix problems with missing packages.
	If successfull build, all files (*.log and *.deb) are copied into the package directory
	If failed also all files are copied but a FAILURE.deb is created inside the package directory.

	usage:
	  buildPackages.sh END|CLEAN|RECOVER
		END		End a schroot session(-force)
		CLEAN		End and clean up a schroot session
		RECOVER		recovers an oprhan schroot session
	  buildPackages.sh DIST PACKAGE_SELECT SCOPE MODE
		DIST		*jessie* (default) or other schoot environment
				If set up with setup.sh it is of this form: LUKS-DIST-ARCH
		PACKAGE_SELECT	buildPackages.txt (default) = selected packages (from PACKAGE_BASE)
		SCOPE		ALL (default) = build all packages from PACKAGE_SELECT
				otherwise = name of a single package from PACKAGE_SELECT to build
		MODE		NONE (default) = "normal" operation, no clean / rebuild
		                REBUILD = clen up prior builds, reload package and rebuild

