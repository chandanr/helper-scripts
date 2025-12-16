#!/bin/bash

dev=/dev/loop0
mntpnt=/mnt/
testfile=${mntpnt}/testfile

umount $dev > /dev/null 2>&1

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

touch $testfile
testino=$(stat -c "%i" $testfile)
echo "$testfile Inode number: $testino"

dirino=$(stat -c "%i" $mntpnt)
echo "$mntpnt Inode number: $dirino"

umount $dev > /dev/null 2>&1

mount $dev $mntpnt
if [[ $? != 0 ]]; then
	echo "Unable to mount $dev"
	exit 1
fi

perf record \
     -e probe:iput --filter "inode == $testino" \
     -e probe:igrab --filter "inode == $testino" \
     -e probe:__iget --filter "inode == $testino" \
     -e xfs:xfs_lookup --filter "dp_ino == $dirino" \
     -e 'xfs:*' \
     -g -a -- xfs_io -f -s -c "pwrite 0 4k" $testfile

