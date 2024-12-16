#!/bin/bash

device=/dev/loop0
sdev=$(basename $device)
mntpnt=/mnt/
testfile=${mntpnt}/testfile
punch_alternate=/root/repos/xfstests-dev/src/punch-alternating

umount $device > /dev/null 2>&1

mkfs.xfs -f $device
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

mount $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

xfs_io -f -c "pwrite 0 256M" $testfile

$punch_alternate $testfile

ino=$(stat -c "%i" $testfile)
echo "Inode number = $ino"

echo 1 > /sys/fs/xfs/${sdev}/errortag/log_item_pin

# cur->bc_ino.ip->i_ino
perf record \
     -e xfs:xfs_trans_log_buf \
     -e probe:xfs_btree_log_recs \
     -g -a -- xfs_io -c "falloc 280M 4k" $testfile

xfs_io -x -c "shutdown -f" $testfile

echo 0 > /sys/fs/xfs/${sdev}/errortag/log_item_pin

umount $device


