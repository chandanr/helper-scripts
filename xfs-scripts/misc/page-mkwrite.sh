#!/bin/bash

device=/dev/loop0
mntpnt=/mnt/
testfile=/mnt/testfile

umount $device > /dev/null 2>&1

echo "Creating fs"
mkfs.xfs -f -m reflink=1 $device &> /dev/null
if [[ $? != 0 ]]; then
	echo "mkfs.xfs failed.\n"
	exit 1
fi

echo "Mounting fs"
mount $device $mntpnt > /dev/null 2>&1
if [[ $? != 0 ]]; then
	echo "mount failed.\n"
	exit 1
fi

xfs_io -s -f -c "pwrite 0 $((4096 * 3))" $testfile

echo 3 > /proc/sys/vm/drop_caches

ino=$(stat -c '%i' $testfile)

echo "Inode number: $ino"

perf record \
     -e 'xfs:*' \
     -a -g -- \
     xfs_io -c "mmap -rw 0 4k" -c "mwrite 0 4k" $testfile
