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

mount $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

nr_blks=$((32 * 1024))
nr_blks=$((nr_blks / 4096))
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

/root/repos/helper-scripts/xfs-scripts/misc/xfs-unlink-inode-before-swapext $source $donor $shortdev
if [[ $? != 0 ]]; then
	echo "Failed to swap forks"
	ret=1
else
	echo "Successfully swapped forks"
	ret=0
fi

exit $ret

umount $device

