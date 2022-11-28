#!/usr/bin/zsh -f

device=/dev/loop0
shortdev=$(basename $device)

mntpnt=/mnt/
testfile=${mntpnt}/testfile
fragmentfile=${mntpnt}/fragmentfile
punchprog=/root/repos/xfstests-dev/src/punch-alternating

errortag=/sys/fs/xfs/${shortdev}/errortag/bmap_alloc_minlen_extent

umount $device > /dev/null 2>&1

echo "Create fs"
mkfs.xfs -K -f -d size=2G -m reflink=1 $device &>/dev/null
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

echo "Mount fs"
mount $device $mntpnt &>/dev/null
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

echo "Fragment FS"
xfs_io -f -c "pwrite 0 1G" $fragmentfile &>/dev/null
sync
$punchprog $fragmentfile &>/dev/null
echo -n 1 > $errortag

echo "Create test file"
touch $testfile
ino=$(stat -c '%i' $testfile)
echo "Inode number: $ino"

echo "Perform direct io write"
perf record \
     -e xfs:xfs_file_direct_write \
     -e probe:xfs_bmapi_write \
     -g -a -- \
     xfs_io -d -c "pwrite -b 1M 0 10M" $testfile
