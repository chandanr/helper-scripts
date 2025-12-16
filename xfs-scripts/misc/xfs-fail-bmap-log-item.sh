#!/bin/bash

device=/dev/loop0
shortdev=$(basename $device)
mntpnt=/mnt/

source=/mnt/source
donor=/mnt/donor

umount $device > /dev/null 2>&1

mkfs.xfs -K -f -m reflink=1,rmapbt=1 $device
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

mount -o wsync $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

xfs_io -f -c "pwrite 0 32k" $source >/dev/null 2>&1
xfs_io -f -c "pwrite 0 32k" $donor >/dev/null 2>&1
sync

xfs_io -f -s -c "pwrite 32k 4k" $source >/dev/null 2>&1
xfs_io -f -c "reflink $source 32k 4k 4k" $source >/dev/null 2>&1
xfs_io -f -c "truncate 32k" $source >/dev/null 2>&1

filefrag -v -b4096 $source
filefrag -v -b4096 $donor

source_ino=$(stat -c '%i' $source)
donor_ino=$(stat -c '%i' $donor)

echo "Source Inode number: $source_ino"
echo "Donor Inode number: $donor_ino"

echo 1 > /sys/fs/xfs/${shortdev}/errortag/bmap_finish_one

perf record -e 'xfs:*' -g -a -- \
     xfs_io -c "swapext $donor" $source

# perf record -e probe:xfs_log_unmount \
#      -e probe:xfs_log_writable -a -g --
# umount $device

# echo "After swapext"
# filefrag -v -b4096 $source
# filefrag -v -b4096 $donor
