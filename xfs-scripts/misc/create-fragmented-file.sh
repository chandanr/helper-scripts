#!/usr/bin/zsh -f

dev=/dev/loop0
rtdev=/dev/loop1
mntpnt=/mnt/
punch_alternate=/root/repos/xfstests-dev/src/punch-alternating
testfile=${mntpnt}/testfile
testdir=${mntpnt}/testdir

mkfs.xfs -f -r rtdev=${rtdev} $dev
if [[ $? != 0 ]]; then
	echo "Unable to mkfs.xfs $dev"
	exit 1
fi

mount -o rtdev=${rtdev} $dev $mntpnt
if [[ $? != 0 ]]; then
	echo "Unable to mount $dev"
	exit 1
fi


xfs_io -f -R -c "pwrite 0 10M" -c sync $testfile

$punch_alternate $testfile

ino=$(stat -c '%i' $testfile)

echo "Inode number: $ino"

umount $mntpnt
