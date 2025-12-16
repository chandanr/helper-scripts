#!/usr/bin/bash

dev=/dev/loop0
mntpnt=/mnt/
testfile=${mntpnt}/testfile

umount $mntpnt

mkfs.xfs -f $dev
if [[ $? != 0 ]]; then
	echo "Unable to mkfs.xfs $dev"
	exit 1
fi

mount $dev $mntpnt
if [[ $? != 0 ]]; then
	echo "Unable to mount $dev"
	exit 1
fi

xfs_io -f -c 'falloc 0 1g' $testfile

perf record -e xfs:xfs_unwritten_convert -g -a -- \
     xfs_io -d -s -c 'pwrite 4k 4k' $testfile
