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

Build an arm boot image
=======================
NO the raspberry PI 2 or 3 are NOT the target platforms. But they are arm platforms to learn, to try out anything and to test. And - there's no BIOS flashed as firmware on any chip, it is software on the boot medium which can be more easily checked before beeing used than flashed firmware inside of a chip.
Additionally I decided to go the u-boot way for some reasons:
- abstract the hardware driven 1st level bootloader from a OS loader (which is the u-boot)
- if u-boot is not the propper OS loader, it can be changed more easily than the 1st level loader
- source code is available to learn how that loader works

u-boot may - !!! but must not !!! - be the final choice, it is just a point I started building bootable images for my rpi platform.

Note also, to boot,
- debian needs a non-FAT "boot" partition
- and rpi2 needs a FAT partition as first partition
Thus, the first partition is named "firmware" (FAT) mounted to /boot/firmware, the second "boot" (efsX) mounted to /boot.

1.) Building the debian armhf image and rpi2 boot image
Sources
	- hoedelmosers way (rasbian instead of debian)	
	
	https://github.com/andrius/build-raspbian-image
	https://blog.kmp.or.at/build-your-own-raspberry-pi-image/
	#Open process but builds raspbian images from prebuild rasbian chroots. The efforts to adapt that stuff to debian seems to be not less/low.
	
	- https://github.com/drtyhlpr/rpi2-gen-image
	
	# Also open and strict debootstrap driven process.
	# This is what I used to build an arm debian image for my rpi2
	git clone https://github.com/drtyhlpr/rpi23-gen-image.git
	cd rpi2-gen-image
	./rpi23-gen-image.sh

2.) Switching to u-boot

u-boot must be loaded by bootloader.bin instead of kernel7.image. First I had to set up a cross compiling environment. With Debian jessie there is no gcc-arm-linux-gnueabihf package (comes with stretch ...), so I followed Debians proposals/documentation https://wiki.debian.org/CrossToolchains#For_jessie_.28Debian_8.29 for "For jessie (Debian 8)". To build the u-boot loader I additionally installed
- device-tree-compiler (see apt)
- u-boot-tools (also see apt, contains mkimage)
Note: If you've set up Debian backports or anything else, you have to disable that apt sources temporarely. Most important is the following command, note that this may influence your dev environment also (example for jessie; may be added also to apt.conf):

	echo "APT::Default-Release \"jessie\";" > /etc/apt/apt.conf.d/20defaultrelease

With that toolchain I was able to cross compile the armhf u-boot loader on a non-arm platform, see https://blog.night-shade.org.uk/2015/05/booting-a-raspberry-pi2-with-u-boot-and-hyp-enabled/
	
	export ARCH=arm
	export CROSS_COMPILE=arm-linux-gnueabihf-
	git clone git://git.denx.de/u-boot.git
	cd u-boot
	make rpi_2_defconfig
	make all
	
I decided to start the work with a "script" u-boot image (see also https://blog.night-shade.org.uk/2015/05/booting-a-raspberry-pi2-with-u-boot-and-hyp-enabled/). Note: mkimage can be executed on a non-arm platform, it does not matter to which path boot.scr will be written. Anyhow, the gererated boot.scr must be finally placed (or copied) into the arm boot partition. 

I skipped the chapter "serial console" with manual booting debian. The boot.scr script noted above I copied 1:1 from the documentation into a file /tmp/boot_arm_deb.script, there's no magic (except the RPI2 machine id):

	# Tell Linux that it is booting on a Raspberry Pi2
	setenv machid 0x00000c42
	# Set the kernel boot command line
	setenv bootargs "earlyprintk console=tty0 console=ttyAMA0 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait noinitrd"
	# Save these changes to u-boot's environment
	saveenv
	# Load the existing Linux kernel into RAM
	fatload mmc 0:1 ${kernel_addr_r} kernel7.img
	# Boot the kernel we have just loaded
	bootz ${kernel_addr_r}

The mkimage command I executed on the non-arm platform 
	
	mkimage -A arm -O linux -T script -C none -a 0x00000000 -e 0x00000000 -n "RPi2 U-Boot Script" -d /tmp/boot_arm_deb.script ./boot.scr

The u-boot.bin (compiled) and boot.scr (mkimage) both must be copied into the rpi2's boot section (firmware) and finally the config.txt of the rpi2's boot section must be modified (u-boot.bin instead of kernel7.img)
	
	parted <./rpi23-gen-image.sh image>
	> unit B
    Units as byte
	> print
	prints the partitions and their start position in byte
	> quit
	losetup -o <.first partition start pos in byte> -f <./rpi23-gen-image.sh image> 
	losetup -a 
	# search your image /dev/loopX device; probably the last
	# and mount it
	mount /dev/loopX <.any mount pont>
	# now access the mounted rpi2's boot partition
	cp u-boot.bin <.any mount pont>
	cp boot.scr <.any mount pont> 
	vi config.txt
		kernel=u-boot.bin
	# unmount and release
	umount /dev/loopX
	losetup -d /dev/loopX

"burn" to an usb stick

	dd if=<./rpi23-gen-image.sh image> of=/dev/<.usb device> bs=4M; sync
