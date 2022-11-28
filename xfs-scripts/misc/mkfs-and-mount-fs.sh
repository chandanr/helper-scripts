#!/usr/bin/zsh -f

device=/dev/loop0
shortdev=$(basename $device)

mntpnt=/mnt/
file1=${mntpnt}/file1
file2=${mntpnt}/file2

umount $device &>/dev/null

echo "Create FS"
mkfs.xfs -K -f  -m reflink=1 $device &>/dev/null
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

echo "Mount FS"
mount $device $mntpnt &>/dev/null
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

findmnt $device
