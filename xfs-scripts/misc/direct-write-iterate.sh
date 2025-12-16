#!/usr/bin/bash

device=/dev/loop0
mntpnt=/mnt/
testfile=${mntpnt}/testfile

umount $device > /dev/null 2>&1

mkfs.xfs -K -f $device
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

mount $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

# onegb=$((1 << 30))

onegb=$((4 * 1024 * 1024))

for i in $(seq 0 1); do
	echo "Writing to range $(($i * $onegb)) $(($i * $onegb + $onegb))"
	xfs_io -d -f -c "pwrite -b 4M $(($i * $onegb)) $onegb" $testfile
done

inode_nr=$(stat -c '%i' $testfile)
echo "Inode number = $inode_nr"
