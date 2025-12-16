#!/usr/bin/bash

device=/dev/loop0
mntpnt=/mnt/
testfile=${mntpnt}/testfile

umount $device > /dev/null 2>&1

mkfs.xfs -K -f -m bigtime=0,finobt=0 $device
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

mount $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

echo "Shutting down $mntpnt"
perf record \
     -e probe:xfs_log_unmount \
     -e xfs:xfs_force_shutdown \
     -g -a \
     -- xfs_io -r -x -c 'shutdown' $mntpnt

