#!/usr/bin/zsh -f

device=/dev/loop1
mntpnt=/mnt/
testfile=/mnt/testfile

umount $device > /dev/null 2>&1

mkfs.xfs -K -f -m reflink=1 $device
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

mount -o usrquota,grpquota $device $mntpnt
# mount -o quota $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

chmod 0777 $mntpnt
su - fsgqa -c "xfs_io -f -s -c 'pwrite 0 8k' $testfile"

# umount $mntpnt
# xfs_quota -x -c "disable" $mntpnt
xfs_quota -x -c "off" $mntpnt
