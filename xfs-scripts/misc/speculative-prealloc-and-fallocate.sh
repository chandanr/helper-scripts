#!/bin/bash

device=/dev/loop0
sdev=$(basename $device)
mntpnt=/mnt/
testfile=${mntpnt}/testfile
punch_file=${mntpnt}/punch_file
punch_alternate=/root/repos/xfstests-dev/src/punch-alternating

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


# /sys/fs/xfs/loop0/errortag/bmap_alloc_minlen_extent

fallocate -o 0 -l 512M $punch_file
$punch_alternate $punch_file

exec 3>${testfile}

dd if=/dev/zero bs=68k count=1 1>&3
sync

echo -n 1 > /sys/fs/xfs/${sdev}/errortag/bmap_alloc_minlen_extent

dd if=/dev/zero bs=1k count=4 1>&3
sync

echo -n 0 > /sys/fs/xfs/${sdev}/errortag/bmap_alloc_minlen_extent

fallocate -n -o 10M -l 4k $testfile

echo "--- Before closing fd ---"
filefrag -b1 -v $testfile

exec 3>&-

echo "--- After closing fd ---"
filefrag -b1 -v $testfile

umount $device

mount $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

echo "--- After unmounting/mounting filesystem ---"
filefrag -b1 -v $testfile

# --- Before closing fd ---
# Filesystem type is: 58465342
# File size of /mnt//testfile is 73728 (73728 blocks of 1 bytes)
#  ext:     logical_offset:        physical_offset: length:   expected: flags:
#    0:        0..   69631:  539099136.. 539168767:  69632:
#    1:    69632..   73727:      98304..    102399:   4096:  539168768:,eof
#    2:    73728..  196607:          0..         0:      0:             unknown_loc,delalloc,eof
#    3: 10485760..10489855:     106496..    110591:   4096:   10412032: last,unwritten,eof
# /mnt//testfile: 4 extents found
# --- After closing fd ---
# Filesystem type is: 58465342
# File size of /mnt//testfile is 73728 (73728 blocks of 1 bytes)
#  ext:     logical_offset:        physical_offset: length:   expected: flags:
#    0:        0..   69631:  539099136.. 539168767:  69632:
#    1:    69632..   73727:      98304..    102399:   4096:  539168768:,eof
#    2:    73728..  196607:          0..         0:      0:             unknown_loc,delalloc,eof
#    3: 10485760..10489855:     106496..    110591:   4096:   10412032: last,unwritten,eof
# /mnt//testfile: 4 extents found
# --- After unmounting/mounting filesystem ---
# Filesystem type is: 58465342
# File size of /mnt//testfile is 73728 (73728 blocks of 1 bytes)
#  ext:     logical_offset:        physical_offset: length:   expected: flags:
#    0:        0..   69631:  539099136.. 539168767:  69632:
#    1:    69632..   73727:      98304..    102399:   4096:  539168768: last,eof
# /mnt//testfile: 2 extents found
