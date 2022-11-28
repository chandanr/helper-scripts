#!/usr/bin/bash

device=/dev/loop0
mntpnt=/mnt/
testdir=/mnt/testdir

umount $device > /dev/null 2>&1

mkfs.xfs -K -f -m reflink=1 $device
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

mount $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

mkdir $testdir

for i in $(seq 1 10000); do
	touch ${testdir}/$file-${i}.bin
done

sync

echo 3 > /proc/sys/vm/drop_caches
