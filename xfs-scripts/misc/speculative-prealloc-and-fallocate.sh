#!/bin/bash

device=/dev/loop0
sdev=$(basename $device)
mntpnt=/mnt/
testfile=${mntpnt}/testfile

umount $device > /dev/null 2>&1

mkfs.xfs -f $device
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

mount $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

exec 3>${testfile}

dd if=/dev/zero bs=68k count=1 1>&3
sync

dd if=/dev/zero bs=4k count=1 1>&3

sync

fallocate -n -o 10M -l 4k $testfile

echo "--- Before closing fd ---"
filefrag -b1 -v $testfile

exec 3>&-

echo "--- After closing fd ---"
filefrag -b1 -v $testfile

umount $device

# Extent layout after umount and mount
# # filefrag -b1 -v /mnt/testfile
# Filesystem type is: 58465342
# File size of /mnt/testfile is 73728 (73728 blocks of 1 bytes)
#  ext:     logical_offset:        physical_offset: length:   expected: flags:
#    0:        0..   73727:      98304..    172031:  73728:            ,eof
#    1:    73728..  196607:     172032..    294911: 122880:             unwritten,eof
#    2: 10485760..10489855:   10584064..  10588159:   4096:             last,unwritten,eof
# /mnt/testfile: 1 extent found
