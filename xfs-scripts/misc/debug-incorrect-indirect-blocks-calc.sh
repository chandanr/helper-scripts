#!/usr/bin/zsh -f

# set -x

for line_nr in 261 339 385 441 519; do
	if [[ $line_nr == 339 ]]; then
		extra_var="temp:u64 left_filling_allocated:s32 left_filling_da_new:u64"
	else
		extra_var=""
	fi
	
	perf probe -a \
	     "xfs_bmap_add_extent_delay_real:${line_nr} inode=bma->ip->i_ino:u64 state:s32 ${extra_var} da_old:u64 da_new:u64" \
	     --vmlinux=/root/junk/build/linux/vmlinux
done

# i=0; while [ 1 ]; do ((i = i + 1)); echo "----- $i ----"; perf record -e probe:xfs_bmap_add_extent_delay_real_L261 -e probe:xfs_bmap_add_extent_delay_real_L339 -e probe:xfs_bmap_add_extent_delay_real_L385 -e probe:xfs_bmap_add_extent_delay_real_L441 -e probe:xfs_bmap_add_extent_delay_real_L519 -g -a -- ./check xfs/538 || break; done
