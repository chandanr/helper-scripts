#!/bin/bash

dev=/dev/loop0
mntpnt=/mnt/
testfile_prefix=${mntpnt}/testfile

umount $dev > /dev/null 2>&1

mkfs.xfs -f  $dev
if [[ $? != 0 ]]; then
	echo "Unable to mkfs.xfs $dev"
	exit 1
fi

mount $dev $mntpnt
if [[ $? != 0 ]]; then
	echo "Unable to mount $dev"
	exit 1
fi

for i in $(seq 1 128); do
	touch ${testfile_prefix}-${i}
done

sync

echo 3 > /proc/sys/vm/drop_caches

# rm -rf ${testfile_prefix}*
