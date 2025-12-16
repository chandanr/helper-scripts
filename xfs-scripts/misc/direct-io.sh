#!/usr/bin/zsh -f

device=/dev/loop0
mntpnt=/mnt/
testfile=${mntpnt}/testfile

umount $device > /dev/null 2>&1

mkfs.xfs -K -f -m bigtime=0,finobt=0 $device
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

mount $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

perf record -e xfs:xfs_end_io_direct_write -g -a \
     -- xfs_io -fd -c 'pwrite 0 8M' $testfile

sync

# perf record -e probe:iomap_dio_iter -g -a -- xfs_io -d -f -c 'pwrite -S 0xabababab 4096 4096' $testfile
