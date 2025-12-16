#!/bin/bash

dev=/dev/loop0
mntpnt=/mnt/
testdir=/mnt/testdir/
testfile=${testdir}/testfile

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

mkdir $testdir
for i in $(seq 1 100); do
	touch ${testdir}/file-${i}.bin
done

echo 3 > /proc/sys/vm/drop_caches

umount $dev
mount $dev $mntpnt

perf record \
     -e xfs:xfs_buf_item_* \
     -e xfs:xfs_buf_item_relse \
     -e xfs:xfs_buf_item_release \
     -e xfs:xfs_buf_item_pin \
     -e xfs:xfs_buf_item_push \
     -e xfs:xfs_buf_item_unpin_stale \
     -e xfs:xfs_buf_init \
     -e xfs:xfs_buf_get \
     -e xfs:xfs_buf_read \
     -e xfs:xfs_buf_rele \
     -e xfs:xfs_buf_hold \
     -e xfs:xfs_trans_read_buf \
     -e xfs:xfs_dir2_node_addname \
     -e xfs:xfs_dir2_leaf_addname \
     -e xfs:xfs_dir2_block_addname \
     -e xfs:xfs_trans_bjoin \
     -e xfs:xfs_buf_delwri_queue \
     -e printk:console \
     -g -a  -- \
     xfs_io -s -f -c 'pwrite 0 4k' $testfile

# xfs_io -f -c 'pwrite 0 4k' $testfile

# perf record \
#      -e xfs:xfs_buf_item_* \
#      -e xfs:xfs_buf_item_relse \
#      -e xfs:xfs_buf_item_release \
#      -e xfs:xfs_buf_item_pin \
#      -e xfs:xfs_buf_item_push \
#      -e xfs:xfs_buf_item_unpin_stale \
#      -e xfs:xfs_buf_init \
#      -e xfs:xfs_buf_get \
#      -e xfs:xfs_buf_read \
#      -e xfs:xfs_buf_rele \
#      -e xfs:xfs_buf_hold \
#      -e xfs:xfs_trans_read_buf \
#      -e xfs:xfs_dir2_node_addname \
#      -e xfs:xfs_dir2_leaf_addname \
#      -e xfs:xfs_dir2_block_addname \
#      -e xfs:xfs_trans_bjoin \
#      -e xfs:xfs_buf_delwri_queue \
#      -e printk:console \
#      -g -a -- umount $mntpnt
