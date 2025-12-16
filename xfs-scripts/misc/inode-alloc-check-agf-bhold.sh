#!/usr/bin/bash

device=/dev/loop0
shortdev=$(basename $device)

mntpnt=/mnt/
testdir=/mnt/testdir
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

echo "Create test dir"
mkdir $testdir
if [[ $? != 0 ]]; then
	echo "Unable to create $testdir"
	exit 1
fi

echo "Create fragmented file"
xfs_io -f -c "pwrite 0 512M" $fragmentfile &>/dev/null
sync

$punchprog $fragmentfile


echo "Allocate block sized extent from now onwards"
echo -n 1 > $errortag

# echo "Create new inodes"
# for in $(seq 1 5000); do
# 	touch ${testdir}/${i}
# done
