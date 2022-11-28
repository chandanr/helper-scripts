#!/usr/bin/zsh -f

device=/dev/loop0
mntpnt=/mnt/
testfile=${mntpnt}/testfile
punch_alternate=/root/repos/xfstests-dev/src/punch-alternating

nrext64=0

mkfs.xfs -K -f -i nrext64=${nrext64} $device
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

mount $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

xfs_io -f -c 'pwrite 0 10M' $testfile

$punch_alternate $testfile

ls -i $testfile

umount $mntpnt
