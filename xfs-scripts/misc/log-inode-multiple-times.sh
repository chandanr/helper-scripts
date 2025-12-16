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

touch $testfile

ino=$(stat -c '%i' $testfile)

printf "Inode number: 0x%x\n" $ino

echo "Pin log items"
echo 1 > /sys/fs/xfs/${shortdev}/errortag/log_item_pin

echo "Write 4k bytes"
xfs_io -s -c "pwrite 0 4k" $testfile

sync

echo "Truncate file"
truncate -s 0 $testfile

sync

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
