#!/usr/bin/bash

device=/dev/loop0
mntpnt=/mnt/
testfile=${mntpnt}/testfile

umount $device > /dev/null 2>&1

echo "Creating fs"
mkfs.xfs -f -m reflink=1 $device &> /dev/null
if [[ $? != 0 ]]; then
	echo "mkfs.xfs failed.\n"
	exit 1
fi

echo "Mounting fs"
mount $device $mntpnt &> /dev/null
if [[ $? != 0 ]]; then
	echo "mount failed.\n"
	exit 1
fi

echo "Fallocating test file"
xfs_io -f -c "falloc 0 1G" $testfile

echo "Mmap based read of test file"
xfs_io -c "mmap 0 512M" -c "mread 0 512M" $testfile
