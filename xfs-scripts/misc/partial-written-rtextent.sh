#!/bin/bash

dev=/dev/loop0
rtdev=/dev/loop1
mntpnt=/mnt/

testfile=${mntpnt}/testfile

mkfs.xfs -f -r rtdev=/dev/loop1,extsize=12288 $dev
if [[ $? != 0 ]]; then
	echo "Unable to mkfs.xfs $dev"
	exit 1
fi

mount -o rtdev=/dev/loop1 $dev $mntpnt
if [[ $? != 0 ]]; then
	echo "Unable to mount $dev"
	exit 1
fi


xfs_io -f -R -s -c 'pwrite 0 4k' $testfile
lsattr $testfile


