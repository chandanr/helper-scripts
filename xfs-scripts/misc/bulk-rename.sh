#!/bin/bash

device=/dev/loop1
mntpnt=/mnt/
srcdir=${mntpnt}/srcdir
dstdir=${mntpnt}/dstdir

umount $device > /dev/null 2>&1

mkfs.xfs -K -f -m reflink=1 $device
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

mount -o uquota $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

chmod 0777 $mntpnt

su - fsgqa -c "mkdir $srcdir"
su - fsgqa -c "mkdir $dstdir"

seq 1 840 | while read -r nr; do
	fname=$(printf "%010d" $nr)
	fname=${srcdir}/${fname}
	su - fsgqa -c "touch $fname"
done

sync

perf record \
     -e xfs:xfs_trans_mod_dquot \
     -e xfs:xfs_trans_mod_dquot_before \
     -g -a &
perf_pid=$!

echo "Moving file to $dstdir"
seq 1 840 | while read -r nr; do
	fname=$(printf "%010d" $nr)
	fname=${srcdir}/${fname}
	su - fsgqa -c "mv $fname ${dstdir}"
done

kill -2 $perf_pid
wait $perf_pid

exit 0
