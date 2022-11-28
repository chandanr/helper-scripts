#!/usr/bin/bash

device=/dev/loop0
shortdev=$(basename $device)

mntpnt=/mnt/
testfile=${mntpnt}/testfile
fragmentfile=${mntpnt}/fragmentfile
punchprog=/root/repos/xfstests-dev/src/punch-alternating

errortag=/sys/fs/xfs/${shortdev}/errortag/bmap_alloc_minlen_extent

umount $device > /dev/null 2>&1

mkfs.xfs -K -f -d size=20G -m reflink=1 $device
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

mount $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

echo "Fragment FS"
xfs_io -f -c "pwrite 0 10G" $fragmentfile
sync
$punchprog $fragmentfile
echo -n 1 > $errortag

xfs_io -f -c "pwrite 0 2G" $testfile

echo "Sync range"
perf record -e probe:xfs_bmapi_convert_delalloc -a -g -- xfs_io -c "sync_range 1G 4k" $testfile

