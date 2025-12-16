#!/bin/bash

memfile=/dev/memfile

if [[ $# != 1 ]]; then
	echo "Usage: $0 <memory in MiB>"
	exit 1
fi

mem=$1

dev=/dev/loop0
mntpnt=/mnt/
testfile=${mntpnt}/testfile

umount $dev > /dev/null 2>&1

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

touch $testfile
ino=$(stat -c "%i" $testfile)
echo "${testfile}: inode number = $ino"

echo "Consuming ${mem}MiB memory"

rm -rf $memfile

./record-inode-during-memory-shrink.bt $ino -c "./consume-memory ${mem}"

# perf record \
#      -e probe:xfs_fs_drop_inode__return \
#      -e probe:xfs_fs_drop_inode \
#      -e probe:xfs_fs_destroy_inode \
#      -e xfs:xfs_inode_inactivating \
#      -g -a -- consume-memory ${mem}

exit 0
