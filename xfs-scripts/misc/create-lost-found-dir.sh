#!/bin/bash

device=/dev/loop0
mountpoint=/mnt
lost_found="${mountpoint}/lost+found"

umount $device > /dev/null 2>&1

mkfs.xfs -f $device
if [ $? != 0 ]; then
	echo "mkfs.xfs failed"
	exit 1
fi

mount $device $mountpoint
if [ $? != 0  ]; then
	echo "mount failed"
	exit 1
fi

mkdir $lost_found
if [ $? != 0  ]; then
	echo "mkdir lost+found failed"
	exit 1
fi

touch ${lost_found}/somefile
ino=$(stat -c '%i' ${lost_found}/somefile)
echo "Inode number = $ino"

mv ${lost_found}/somefile ${lost_found}/${ino}

touch ${lost_found}/obfuscate-this

echo "Create extra files"
mkdir ${mountpoint}/extra-dir
for i in $(seq 1 5); do
	echo "Create extra file: extra-file-${i}"
	touch ${mountpoint}/extra-dir/extra-file-${i}
done
