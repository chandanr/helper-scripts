#!/bin/bash

loop_device=/dev/loop0
flakeyname=flakeytest
device=/dev/mapper/${flakeyname}

mntpnt=/mnt/
testfile=${mntpnt}/testfile

umount $device > /dev/null 2>&1
dmsetup remove --deferred $flakeyname > /dev/null 2>&1
if [[ $? == 0 ]]; then
	udevadm wait --removed $device > /dev/null 2>&1
fi

SECTORS=$(blockdev --getsz /dev/loop0)

echo "Create flakey device"
dmsetup create $flakeyname --table "0 $SECTORS flakey $loop_device 0 180 0"
if [[ $? != 0 ]]; then
	echo "Flakey device creation failed."
	exit 1
fi
udevadm wait $device
shortdev=$(realpath $device | xargs basename)

mkfs.xfs -K -f -m reflink=1,rmapbt=0 $device > /dev/null 2>&1
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

mount -o wsync $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

echo "Create test file"
xfs_io -s -f -c "pwrite 0 32k" $testfile > /dev/null 2>&1

ino=$(stat -c '%i' $testfile)
printf "Inode number: 0x%x\n" $ino

echo "Extend test file"
xfs_io -c "pwrite 32k 4k" $testfile > /dev/null 2>&1

echo "Pin log items"
echo 1 > /sys/fs/xfs/${shortdev}/errortag/log_item_pin

echo "Reflink extent"
perf record \
     -e probe:xfs_bmap_unmap_extent \
     -e probe:xfs_bmap_update_log_item \
     -e probe:xfs_bmap_update_finish_item \
     -e probe:xfs_bud_item_release \
     -g -a -- \
     xfs_io -c "reflink $testfile 32k 0 4k" $testfile > /dev/null 2>&1

echo "Fsync-ing"
xfs_io -c fsync $testfile

echo "Extent maps"
filefrag -v -b4096 $testfile

echo "Dropping writes"
dmsetup suspend --nolockfs $flakeyname
if [[ $? != 0 ]]; then
	echo "Flakey device suspend failed."
	exit 1
fi

echo -e "0 $SECTORS flakey $loop_device 0 0 180 1 drop_writes" | \
	dmsetup load $flakeyname
if [[ $? != 0 ]]; then
	echo "Flakey device load failed."
	exit 1
fi

dmsetup resume $flakeyname
if [[ $? != 0 ]]; then
	echo "Flakey device resume failed."
	exit 1
fi

echo "Unpin log items"
echo 0 > /sys/fs/xfs/${shortdev}/errortag/log_item_pin

echo "Umounting device"
umount $device

echo "Removing flakey device"
dmsetup remove --deferred $flakeyname
udevadm wait --removed $device

echo "Contents of the log"
xfs_logprint -t -b -i -o $loop_device
