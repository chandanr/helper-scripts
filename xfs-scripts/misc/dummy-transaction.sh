#!/bin/bash

dev=/dev/loop0
mntpnt=/mnt/
testfile=${mntpnt}/testfile

umount $mntpnt 2>&1 > /dev/null

mkfs.xfs -f $dev
if [[ $? != 0 ]]; then
	echo "Unable to mkfs.xfs $dev"
	exit 1
fi

dmesg -c > /dev/null

mount $dev $mntpnt
if [[ $? != 0 ]]; then
	echo "Unable to mount $dev"
	exit 1
fi

xfs_io -f -c "pwrite 0 4k" $testfile

sync
