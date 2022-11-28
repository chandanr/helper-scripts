#!/usr/bin/bash

dev=/dev/loop0
mntpnt=/mnt/
testfile=${mntpnt}/testfile

umount $dev > /dev/null 2>&1
mkfs.xfs -f $dev
if [[ $? != 0 ]]; then
	echo "Unable to mkfs.xfs $dev"
	exit 1
fi

mount -o allocsize=1G $dev $mntpnt
if [[ $? != 0 ]]; then
	echo "Unable to mount $dev"
	exit 1
fi

perf record \
     -e xfs:xfs_iext_insert \
     -e xfs:xfs_bmap_pre_update \
     -e xfs:xfs_bmap_post_update \
     -e xfs:xfs_iext_remove \
     -g -a -- \
     buffered-write-and-sleep.py 0 4096 $testfile

inode_nr=$(stat -c '%i' $testfile)

echo "Inode number: $inode_nr"

filefrag -b1 -v $testfile

ls -lh $testfile
