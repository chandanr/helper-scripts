#!/usr/bin/zsh -f

dev=/dev/loop0
mntpnt=/mnt/
punch_alternate=/root/repos/xfstests-dev/src/punch-alternating
testfile=${mntpnt}/testfile
testdir=${mntpnt}/testdir

mkfs.xfs -f $dev
if [[ $? != 0 ]]; then
	echo "Unable to mkfs.xfs $dev"
	exit 1
fi

mount $dev $mntpnt
if [[ $? != 0 ]]; then
	echo "Unable to mount $dev"
	exit 1
fi


xfs_io -f -c "pwrite 0 500m" -c sync $testfile

$punch_alternate $testfile

ino=$(stat -c '%i' $testfile)

echo "Inode number: $ino"

umount $mntpnt
