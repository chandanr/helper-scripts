#!/usr/bin/zsh -f

device=/dev/loop0
shortdev=$(basename $device)

mntpnt=/mnt/
file1=${mntpnt}/file1
file2=${mntpnt}/file2
fragmentfile=${mntpnt}/fragmentfile
punchprog=/root/repos/xfstests-dev/src/punch-alternating

errortag=/sys/fs/xfs/${shortdev}/errortag/bmap_alloc_minlen_extent

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

echo "Create unwritten extent"
xfs_io -c "falloc 8k 4k" $file1 &>/dev/null

# filefrag -b4096 -v $file1

# echo "Fragment FS"
# xfs_io -f -c "pwrite 0 5G" $fragmentfile &>/dev/null
# sync
# $punchprog $fragmentfile

# echo "Allocate block sized extent from now onwards"
# echo -n 1 > $errortag

echo "Set cowextsize to 1G"
xfs_io -c "cowextsize 1G" $file1 &>/dev/null
xfs_io -c "cowextsize" $file1

echo "Create 1G delalloc extent in CoW fork"
if (( 0 )); then
	perf record \
	     -e xfs:\* \
	     -e probe:xfs_reflink_allocate_cow -g -a -- \
	     xfs_io -c "pwrite 4k 4k" $file1 &>/dev/null
else
	xfs_io -c "pwrite 4k 4k" $file1 &>/dev/null
fi

echo "Write to unwritten extent"
if (( 1 )); then
	perf record \
	     -e xfs:\* \
	     -e probe:xfs_reflink_allocate_cow \
	     -e probe:xfs_bmapi_write \
	     -g -a -- xfs_io -d -c "pwrite 8k 4k" $file1 &>/dev/null
else
	xfs_io -d -c "pwrite 8k 4k" $file1 &>/dev/null
fi

filefrag -b4096 -v $file1

# echo "Unmount fs"
# perf record -e xfs:\* -g -a -- umount $device &>/dev/null
