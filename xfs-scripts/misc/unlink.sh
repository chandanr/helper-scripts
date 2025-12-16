#!/bin/bash

device=/dev/loop0
mntpnt=/mnt/
testfile1=/mnt/testfile1

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

xfs_io -f -c "pwrite 0 4k" $testfile1

tino1=$(stat -c "%i" $testfile1)

echo "tino1 = $tino1"

sync

umount $device > /dev/null 2>&1

mount $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

# rm $testfile1
# ls -lih $testfile1

perf record -e probe:xfs_inode_item_precommit_L74 \
     -e probe:xfs_inode_item_precommit_L25 \
     -e probe:xfs_inode_item_precommit_L84 \
     -e xfs:xfs_inodegc_worker \
     -e xfs:xfs_inode_inactivating \
     -e probe:xfs_inactive_ifree \
     -e probe:xfs_iunlink_remove \
     -e probe:xfs_buf_item_free \
     -e probe:xfs_inode_item_precommit_L59 \
     -e xfs:* \
     -a -g -- unlink-and-sleep.sh $device $testfile1 20

umount $device


