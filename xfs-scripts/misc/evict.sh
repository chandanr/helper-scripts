#!/bin/bash

dev=/dev/loop0
mntpnt=/mnt/
testfile=${mntpnt}/testfile

umount $mntpnt

mkfs.xfs -f -m bigtime=0,finobt=0 $dev
if [[ $? != 0 ]]; then
	echo "Unable to mkfs.xfs $dev"
	exit 1
fi

mount $dev $mntpnt
if [[ $? != 0 ]]; then
	echo "Unable to mount $dev"
	exit 1
fi


xfs_io -f -c 'pwrite 0 4k' $testfile

ino=$(stat -c '%i' $testfile)

echo "Inode number = $ino"

/usr/bin/echo 3 > /proc/sys/vm/drop_caches

umount $mntpnt
