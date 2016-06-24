#! /bin/bash

# log function with date/time
#
# $1	message to log
function log() {
	echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

# Abort function with date/time
# - if error code > 0 print the message exit with error code
# - otherwise do nothing / skip
#
# $1	exit code
# $2	message to log
function abortOnFailure() {
	if [ "$1" == "0" ]; then
		return 0
	elif [ "$1" != "" ]; then
		echo "[$(date +"%Y-%m-%d %H:%M:%S")] ABORT($1): $2" 1>&2
		exit $1
	fi
}

# Close and unmount the TailsDev environment. 
# Problem: Crypted device can be determined by mount point, but there's no
# link from crypted device (mapper) to loop device (image file)
# - if mount point name given, follows the mount point to the mapped crypted device
# - close the (given/determined) crypted device
# - if image file name given, detach loop device
#
# $1	image file name
# $2	cryptsetup name
#
# returns 1 Current working directory is below mount point
# 	  2 Umount failed
# 	  3 Luks close failed
#	  4 Image file does not exist
#	  5 No loop device found
# 	  6 Detach loop device failed
function umountDev() {
	if="$1"
	cd="$2"
	
	# Unmount and close luks crypted device
	# - set defaults
	if [ "${cd}" == "" ]; then
		cd="TailsDevCrypt"
	fi
	# - get the mount point from cryptsetup name if mounted
	mp="$(mount | grep "/dev/mapper/${cd}" | grep "btrfs" | cut -d' ' -f3)"
	# - check if mounted (= mount point found)
	if [ "${mp}" != "" ]; then
		# - check if cwd is below mount point and umount
		(pwd | grep "${mp}" >/dev/null 2>&1) && return 1
		umount -f "${mp}" || return 2
	fi
	# - check if cd points to a mapper device
	md="$(ls "/dev/mapper/${cd}")"
	if [ -b "${md}" ]; then
		# - close crypted device
		cryptsetup luksClose "${cd}" || return 3
	fi

	# Detach image file loop device
	# - if empty set default name
	if [ "${if}" == "" ]; then
		if="TailsDevCrypt"
	fi
	# - get an absolute path
	export if="$(readlink -f "${if}")"
	# - check if image file exits
	[ -f "${if}" ] || return 4
	ld="$(losetup -a 2>/dev/null | grep "${if}" 2>/dev/null | cut -d':' -f1)"
	# - check if loop device was found
	[ "${ld}" != "" ] || return 5
	# - detach loop device
	losetup -d "${ld}" || return 6
}

# Mount an image file (luks encrypted)
#
# $1 	image file name
# $2	luks name (mapper device name)
# $3	mount point
# 
# returns 1 image file does not exist
#	  2 losetup -f image file failed
#	  3 luksOpen failed
#	  4 mkdir MOUNTPOINT failed
#	  5 mount /dev/mapper/<LUKS> MOUNTPOINT failed
function mountDev() {
	img="$1"
	luks="$2"
	mountpoint="$3"
	[ -f "${img}" ] || return 1
	losetup -f "${img}" || return 2
	export loopDevice="$(losetup -a 2>/dev/null | grep "${img}" 2>/dev/null | cut -d':' -f1)"
	cryptsetup luksOpen "${loopDevice}" "${luks}" || return 3
	mkdir -m 777 -p "${mountpoint}" || return 4
	mount "/dev/mapper/${luks}" "${mountpoint}" || return 5
}

