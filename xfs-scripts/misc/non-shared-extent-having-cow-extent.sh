#!/usr/bin/bash

device=/dev/loop0
shortdev=$(basename $device)

mntpnt=/mnt/
file1=${mntpnt}/file1
file2=${mntpnt}/file2

umount $device &>/dev/null

echo "Create FS"
mkfs.xfs -K -f  -m reflink=1 $device &>/dev/null
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

echo "Mount FS"
mount $device $mntpnt &>/dev/null
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

echo "Create source file"
xfs_io -f -s -c "pwrite 0 8k" $file1 &>/dev/null

echo "Reflink to destination file"
xfs_io -f -c "reflink $file1" $file2 &>/dev/null

# echo "Extended inode flags"
# xfs_io -c "lsattr" $file1 &>/dev/null
# lsattr -l $file1

echo "Set cowextsize to 1G"
xfs_io -c "cowextsize 1G" $file1 &>/dev/null
xfs_io -c "cowextsize" $file1

echo "Create non-shared extent at file offset [8k, 12k]"
xfs_io -s -c "pwrite 8k 4k" $file1 &>/dev/null

echo "Create ~1G delalloc extent"
if (( 1 )); then
	perf record -e xfs:\* -g -a -- \
	     xfs_io -c "pwrite -S 0xabababab 4k 4k" $file1 &>/dev/null
else
	# [0, 1G] delalloc extent inserted in CoW fork
	xfs_io -c "pwrite -S 0xabababab 4k 4k" $file1 &>/dev/null
fi

if (( 0 )); then
	perf record \
	     -e probe:xfs_map_blocks \
	     -e probe:xfs_map_blocks_L59 \
	     -e probe:xfs_convert_blocks \
	     -g -a -- sync
else
	sync
fi


if (( 0 )); then
	perf record \
	     -e probe:xfs_reflink_allocate_cow \
	     -e probe:xfs_bmapi_write \
	     -e probe:xfs_find_trim_cow_extent_L20 \
	     -g -a \
	     -- xfs_io -d -c "pwrite 8k 4k" $file1
else
	xfs_io -d -c "pwrite 8k 4k" $file1
fi
