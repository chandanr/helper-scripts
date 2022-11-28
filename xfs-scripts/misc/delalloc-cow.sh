#!/usr/bin/zsh -f

device=/dev/loop0
mntpnt=/mnt/
file1=${mntpnt}/file1
file2=${mntpnt}/file2

umount $device > /dev/null 2>&1

mkfs.xfs -K -f -m reflink=1 $device
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

mount $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

xfs_io -f -c 'pwrite 0 2G' $file1

sync

cp --reflink=always $file1 $file2

sync

xfs_io -c 'cowextsize 1G' $file1
echo -n "$file1 cowextsize = "
xfs_io -c 'cowextsize' $file1

if (( 1 )); then
	xfs_io -c 'pwrite -S 0xabababab 0 4k' $file1
else
	perf record -e probe:xfs_bmapi_reserve_delalloc_L37 -a -g -- xfs_io -c 'pwrite -S 0xabababab 0 4k' $file1
fi


if (( 1 )); then
	# perf record -e xfs:xfs_inode_clear_cowblocks_tag \
	# 	     -e xfs:xfs_reflink_cancel_cow \
	# 	     -e probe:xfs_reflink_cancel_cow_blocks \
	# 	     -e xfs:xfs_reflink_cancel_cow_range \
	# 	     -e probe:xfs_map_blocks \
	# 	     -e probe:xfs_bmapi_allocate \
	# 	     -e probe:xfs_bmapi_allocate_L77 \
	# 	     -e probe:xfs_end_ioend \
	# 	     -e probe:xfs_inode_free_cowblocks \
	# 	     -e xfs:xfs_reflink_end_cow \
	# 	     -e xfs:xfs_reflink_cow_remap_from \
	# 	     -a -g -- sync

	perf record -e probe:xfs_reflink_allocate_cow_L56 -a -g -- sync
else
	sync
fi

# perf record -e xfs:\* -a -g -- umount $mntpnt

# od -t x1 /mnt/file1
