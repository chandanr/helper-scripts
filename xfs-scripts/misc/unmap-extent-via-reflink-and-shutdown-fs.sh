#!/bin/bash

# Patch to shutdown the filesystem after unmap item has been logged.
#
# diff --git a/fs/xfs/libxfs/xfs_defer.c b/fs/xfs/libxfs/xfs_defer.c
# index bcfb6a4203cdd..5ee3da38f6c36 100644
# --- a/fs/xfs/libxfs/xfs_defer.c
# +++ b/fs/xfs/libxfs/xfs_defer.c
# @@ -228,7 +228,8 @@ xfs_defer_create_intent(
#   */
#  static int
#  xfs_defer_create_intents(
# -	struct xfs_trans		*tp)
# +	struct xfs_trans		*tp,
# +	bool				*has_bmap_intent)
#  {
#  	struct xfs_defer_pending	*dfp;
#  	int				ret = 0;
# @@ -236,6 +237,10 @@ xfs_defer_create_intents(
#  	list_for_each_entry(dfp, &tp->t_dfops, dfp_list) {
#  		int			ret2;
 
# +		if (has_bmap_intent != NULL &&
# +		    dfp->dfp_type == XFS_DEFER_OPS_TYPE_BMAP)
# +			*has_bmap_intent = true;
# +
#  		trace_xfs_defer_create_intent(tp->t_mountp, dfp);
#  		ret2 = xfs_defer_create_intent(tp, dfp, true);
#  		if (ret2 < 0)
# @@ -532,6 +537,7 @@ xfs_defer_finish_noroll(
 
#  	/* Until we run out of pending work to finish... */
#  	while (!list_empty(&dop_pending) || !list_empty(&(*tp)->t_dfops)) {
# +		bool has_bmap_intent;
#  		/*
#  		 * Deferred items that are created in the process of finishing
#  		 * other deferred work items should be queued at the head of
# @@ -541,7 +547,9 @@ xfs_defer_finish_noroll(
#  		 * of time that any one intent item can stick around in memory,
#  		 * pinning the log tail.
#  		 */
# -		int has_intents = xfs_defer_create_intents(*tp);
# +		has_bmap_intent = false;
# +		int has_intents = xfs_defer_create_intents(*tp,
# +							   &has_bmap_intent);
 
#  		list_splice_init(&(*tp)->t_dfops, &dop_pending);
 
# @@ -554,6 +562,9 @@ xfs_defer_finish_noroll(
#  			if (error)
#  				goto out_shutdown;
 
# +			if (has_bmap_intent)
# +				xfs_force_shutdown((*tp)->t_mountp, SHUTDOWN_FORCE_UMOUNT);
# +
#  			/* Relog intent items to keep the log moving. */
#  			error = xfs_defer_relog(tp, &dop_pending);
#  			if (error)
# @@ -707,7 +718,7 @@ xfs_defer_ops_capture(
#  	if (list_empty(&tp->t_dfops))
#  		return NULL;
 
# -	error = xfs_defer_create_intents(tp);
# +	error = xfs_defer_create_intents(tp, NULL);
#  	if (error < 0)
#  		return ERR_PTR(error);
 


# xfs_logprint's output
#
# BUI: cnt:1 total:1 a:0x55f637d07e50 len:48 
# BUI:  #regs: 1	num_extents: 1  id: 0xffff888148eb2000
# (s: 0xc, l: 1, own: 132, off: 0, f: 0x2) 
# CUI: cnt:1 total:1 a:0x55f637d07ee0 len:48 
# CUI:  #regs: 1	num_extents: 2  id: 0xffff88811175c510
# (s: 0xc, l: 1, f: 0x2) 
# (s: 0xa, l: 1, f: 0x1) 
# BUI: cnt:1 total:1 a:0x55f637d07f70 len:48 
# BUI:  #regs: 1	num_extents: 1  id: 0xffff888148eb20d0
# (s: 0xa, l: 1, own: 132, off: 0, f: 0x1)

device=/dev/loop0
mntpnt=/mnt/
src=/mnt/src
dst=/mnt/dst

umount $device > /dev/null 2>&1

mkfs.xfs -f -m reflink=1 $device
if [[ $? != 0 ]]; then
	echo "mkfs failed."
	exit 1
fi

mount $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

xfs_io -f -c "pwrite 0 8k" $src
xfs_io -f -c "pwrite 0 8k" $dst

src_ino=$(stat -c '%i' $src)
dst_ino=$(stat -c '%i' $dst)

echo "Source inode: $src_ino; Destination inode: $dst_ino"

umount $device

mount -o wsync $device $mntpnt
if [[ $? != 0 ]]; then
	echo "mount failed."
	exit 1
fi

echo "Reflink extent"
xfs_io -c "reflink $src 0 0 4k" $dst

umount $device

dst_ino_hex=$(echo $dst_ino | awk '{ printf("0x%x\n", $1); }')
echo "dst_ino_hex = $dst_ino_hex"

perf record \
     -e probe:xfs_bui_item_recover_L31 --filter "inode == $dst_ino" \
     -e xfs:xfs_irele --filter "ino == $dst_ino_hex" \
     -e xfs:xfs_destroy_inode --filter "ino == $dst_ino_hex" \
     -e probe:xfs_fs_drop_inode --filter "inode == $dst_ino" \
     -e probe:xfs_fs_drop_inode__return \
     -e probe:xfs_fs_fill_super \
     -e probe:list_lru_add__return \
     -g -a -- mount $device $mntpnt

# Perf script's output
# 
# mount  2054 [001]  1809.135928: probe:xfs_bui_item_recover_L31: (ffffffff815d555b) inode=132 bi_type=2 counter=1
# 	ffffffff815d555c xfs_bui_item_recover+0x16c ([kernel.kallsyms])
# 	ffffffff815e3665 xlog_recover_process_intents+0xd5 ([kernel.kallsyms])
# 	ffffffff815e6f3e xlog_recover_finish+0x2e ([kernel.kallsyms])
# 	ffffffff815d0a04 xfs_log_mount_finish+0x144 ([kernel.kallsyms])
# 	ffffffff815bf907 xfs_mountfs+0x577 ([kernel.kallsyms])
# 	ffffffff815c606c xfs_fs_fill_super+0x54c ([kernel.kallsyms])
# 	ffffffff81334580 get_tree_bdev+0x150 ([kernel.kallsyms])
# 	ffffffff815c4a35 xfs_fs_get_tree+0x15 ([kernel.kallsyms])
# 	ffffffff8133296a vfs_get_tree+0x2a ([kernel.kallsyms])
# 	ffffffff81362e2e path_mount+0x2fe ([kernel.kallsyms])
# 	ffffffff813637dc __x64_sys_mount+0x10c ([kernel.kallsyms])
# 	ffffffff81fa876b do_syscall_64+0x3b ([kernel.kallsyms])
# 	ffffffff820000e6 entry_SYSCALL_64_after_hwframe+0x6e ([kernel.kallsyms])
# 	    7fcd1aee2cfe __GI___mount+0xe (/usr/lib/x86_64-linux-gnu/libc.so.6)
# 	               0 [unknown] ([unknown])

# mount  2054 [001]  1809.135950:                probe:xfs_irele: (ffffffff815b88a0) inode=132 counter=1
# 	ffffffff815b88a1 xfs_irele+0x1 ([kernel.kallsyms])
# 	ffffffff815e3665 xlog_recover_process_intents+0xd5 ([kernel.kallsyms])
# 	ffffffff815e6f3e xlog_recover_finish+0x2e ([kernel.kallsyms])
# 	ffffffff815d0a04 xfs_log_mount_finish+0x144 ([kernel.kallsyms])
# 	ffffffff815bf907 xfs_mountfs+0x577 ([kernel.kallsyms])
# 	ffffffff815c606c xfs_fs_fill_super+0x54c ([kernel.kallsyms])
# 	ffffffff81334580 get_tree_bdev+0x150 ([kernel.kallsyms])
# 	ffffffff815c4a35 xfs_fs_get_tree+0x15 ([kernel.kallsyms])
# 	ffffffff8133296a vfs_get_tree+0x2a ([kernel.kallsyms])
# 	ffffffff81362e2e path_mount+0x2fe ([kernel.kallsyms])
# 	ffffffff813637dc __x64_sys_mount+0x10c ([kernel.kallsyms])
# 	ffffffff81fa876b do_syscall_64+0x3b ([kernel.kallsyms])
# 	ffffffff820000e6 entry_SYSCALL_64_after_hwframe+0x6e ([kernel.kallsyms])
# 	    7fcd1aee2cfe __GI___mount+0xe (/usr/lib/x86_64-linux-gnu/libc.so.6)
# 	               0 [unknown] ([unknown])

# mount  2054 [001]  1809.136004: probe:xfs_bui_item_recover_L31: (ffffffff815d555b) inode=132 bi_type=1 counter=1
# 	ffffffff815d555c xfs_bui_item_recover+0x16c ([kernel.kallsyms])
# 	ffffffff815e3665 xlog_recover_process_intents+0xd5 ([kernel.kallsyms])
# 	ffffffff815e6f3e xlog_recover_finish+0x2e ([kernel.kallsyms])
# 	ffffffff815d0a04 xfs_log_mount_finish+0x144 ([kernel.kallsyms])
# 	ffffffff815bf907 xfs_mountfs+0x577 ([kernel.kallsyms])
# 	ffffffff815c606c xfs_fs_fill_super+0x54c ([kernel.kallsyms])
# 	ffffffff81334580 get_tree_bdev+0x150 ([kernel.kallsyms])
# 	ffffffff815c4a35 xfs_fs_get_tree+0x15 ([kernel.kallsyms])
# 	ffffffff8133296a vfs_get_tree+0x2a ([kernel.kallsyms])
# 	ffffffff81362e2e path_mount+0x2fe ([kernel.kallsyms])
# 	ffffffff813637dc __x64_sys_mount+0x10c ([kernel.kallsyms])
# 	ffffffff81fa876b do_syscall_64+0x3b ([kernel.kallsyms])
# 	ffffffff820000e6 entry_SYSCALL_64_after_hwframe+0x6e ([kernel.kallsyms])
# 	    7fcd1aee2cfe __GI___mount+0xe (/usr/lib/x86_64-linux-gnu/libc.so.6)
# 	               0 [unknown] ([unknown])

# mount  2054 [001]  1809.136015:                probe:xfs_irele: (ffffffff815b88a0) inode=132 counter=1
# 	ffffffff815b88a1 xfs_irele+0x1 ([kernel.kallsyms])
# 	ffffffff815e3665 xlog_recover_process_intents+0xd5 ([kernel.kallsyms])
# 	ffffffff815e6f3e xlog_recover_finish+0x2e ([kernel.kallsyms])
# 	ffffffff815d0a04 xfs_log_mount_finish+0x144 ([kernel.kallsyms])
# 	ffffffff815bf907 xfs_mountfs+0x577 ([kernel.kallsyms])
# 	ffffffff815c606c xfs_fs_fill_super+0x54c ([kernel.kallsyms])
# 	ffffffff81334580 get_tree_bdev+0x150 ([kernel.kallsyms])
# 	ffffffff815c4a35 xfs_fs_get_tree+0x15 ([kernel.kallsyms])
# 	ffffffff8133296a vfs_get_tree+0x2a ([kernel.kallsyms])
# 	ffffffff81362e2e path_mount+0x2fe ([kernel.kallsyms])
# 	ffffffff813637dc __x64_sys_mount+0x10c ([kernel.kallsyms])
# 	ffffffff81fa876b do_syscall_64+0x3b ([kernel.kallsyms])
# 	ffffffff820000e6 entry_SYSCALL_64_after_hwframe+0x6e ([kernel.kallsyms])
# 	    7fcd1aee2cfe __GI___mount+0xe (/usr/lib/x86_64-linux-gnu/libc.so.6)
# 	               0 [unknown] ([unknown])
