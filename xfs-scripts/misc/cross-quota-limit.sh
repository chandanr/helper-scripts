#!/usr/bin/bash

device=/dev/loop0
mntpnt=/mnt/
testdir=/mnt/testdir

umount $device > /dev/null 2>&1

mkfs.xfs -K -f $device
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

# "quota" option turns on both accounting and limit enforcement.
mount -o quota $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

chmod 0777 $mntpnt

# su - fsgqa -c "mkdir $testdir"

xfs_quota -x -c "limit -u isoft=5 fsgqa" $mntpnt

echo "----- Quota limits: Before -----"
xfs_quota -x -c "report -i -u" $mntpnt

seq 1 5 | while read -r nr; do
	su - fsgqa -c "touch ${mntpnt}/testfile-${nr}.bin"
done

su - fsgqa -c "touch ${mntpnt}/extrafile.bin"

echo "----- Quota limits: After -----"
xfs_quota -x -c "report -i -u" $mntpnt
