#!/usr/bin/zsh -f

dev=/dev/loop0
mntpnt=/mnt/
testfile=${mntpnt}/testfile

umount $dev > /dev/null 2>&1

mkfs.xfs -f $dev ||  { echo "mkfs.xfs failed.\n"; exit 1 }

mount $dev $mntpnt || { echo "mount failed.\n"; exit 1 }

touch $testfile

sync

setfattr -n "trusted.var1" -v "val1" $testfile

touch -m $testfile

sync
