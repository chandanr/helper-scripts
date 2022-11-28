#!/usr/bin/bash

device=/dev/loop0
shortdev=$(basename $device)

mntpnt=/mnt/
file1=${mntpnt}/file1
file2=${mntpnt}/file2
fragmentfile=${mntpnt}/fragmentfile
punchprog=/root/repos/xfstests-dev/src/punch-alternating

errortag=/sys/fs/xfs/${shortdev}/errortag/bmap_alloc_minlen_extent

umount $device > /dev/null 2>&1

echo "Create FS"
mkfs.xfs -K -f  -m reflink=1 $device > /dev/null 2>&1
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

echo "Mount FS"
mount $device $mntpnt > /dev/null 2>&1
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

echo "Create source file"
xfs_io -f -c "pwrite 0 2G" $file1 > /dev/null 2>&1

sync

echo "Create Reflinked file"
xfs_io -f -c "reflink $file1" $file2 &>/dev/null

echo "Set cowextsize"
xfs_io -c "cowextsize 1G" $file1 > /dev/null 2>&1

echo "Fragment FS"
xfs_io -f -c "pwrite 0 5G" $fragmentfile > /dev/null 2>&1
sync
$punchprog $fragmentfile

echo "Allocate block sized extent from now onwards"
echo -n 1 > $errortag

echo "Create ~1GiB delalloc extent in CoW fork"
xfs_io -c "pwrite 0 4k" $file1 > /dev/null 2>&1

sync

# echo "File maps 1"
# filefrag -b4096 -v $file1

echo "Direct I/O write at offset 12k"
if (( 0 )); then
	perf record \
	     -e xfs:\* \
	     -g -a -- \
	     xfs_io -d -c "pwrite 12k 8k" $file1 # > /dev/null 2>&1
else
	xfs_io -d -c "pwrite 12k 8k" $file1 # > /dev/null 2>&1
fi

# echo "File maps 2"
# filefrag -b4096 -v $file1
