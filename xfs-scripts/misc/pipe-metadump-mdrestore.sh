#!/bin/bash

dev0=/dev/loop0
dev1=/dev/loop1
mntpnt=/mnt/

umount $dev0 > /dev/null 2>&1
umount $dev1 > /dev/null 2>&1

echo "Create fs on $dev0"
mkfs.xfs -f $dev0
if [[ $? != 0 ]]; then
	echo "mkfs failed"
	exit 1
fi

echo "Mount fs"
mount $dev0 $mntpnt
if [[ $? != 0 ]]; then
	echo "Mount failed"
	exit 1
fi

echo "Create directories and files"
for d in d1 d2 d3; do
	dir=${mntpnt}/${d}
	mkdir $dir
	for i in $(seq 1 100); do
		xfs_io -f -c 'pwrite 0 4k' ${dir}/file-${i}.bin > /dev/null
	done
done

echo "Umount filesystem"
umount $mntpnt

echo "Test metadump/mdrestore"
xfs_metadump -v 2 -g -a -o $dev0 - | xfs_mdrestore - $dev1
if [[ $? != 0 ]]; then
	echo "metadump/mdrestore failed"
	exit 1
fi

xfs_repair -n $dev1
if [[ $? != 0 ]]; then
	echo "Repair failed"
	exit 1
fi
