#!/usr/bin/zsh -f

device=/dev/loop0
mntpnt=/mnt/

umount $device > /dev/null 2>&1

echo "* Creating filesystem"
mkfs.xfs -K -f  -d size=$((512 * 1024 * 1024)) -m rmapbt=1,reflink=1 -b size=1k -n size=64k $device
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

# echo "* Mounting fs"
# mount $device $mntpnt
# if [[ $? != 0 ]]; then
# 	echo "mount failed."
# 	exit 1
# fi

# echo "* Unmounting fs"
# umount $device

echo "* Upgrading to nrext64"
xfs_admin -O nrext64=1 $device
if [[ $? != 0 ]]; then
	echo "Upgrade to nrext64 failed"
	exit 1
fi


# echo "* Mounting fs again"
# mount $device $mntpnt
# if [[ $? != 0 ]]; then
# 	echo "mount failed."
# 	exit 1
# fi
