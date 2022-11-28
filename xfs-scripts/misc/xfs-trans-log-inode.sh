#!/usr/bin/bash

device=/dev/loop0
mntpnt=/mnt/
testfile=/mnt/testfile

umount $device > /dev/null 2>&1

mkfs.xfs -K -f -m reflink=1 $device
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

mount $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

touch $testfile

sync

xfs_io -f -c 'pwrite 0 4k' $testfile
