#!/usr/bin/bash

device=/dev/disk/by-partuuid/9c5ba863-01
mntpnt=/mnt/
popdir=/root/repos/xfstests-dev/src/popdir.pl

# umount $device > /dev/null 2>&1

# mkfs.xfs -K -f -m reflink=0,rmapbt=0 -d agcount=50 $device
# if [[ $? != 0 ]]; then
# 	echo "mkfs failed."
# 	exit 1
# fi

# mount $device $mntpnt
# if [[ $? != 0 ]]; then
# 	echo "mount failed."
# 	exit 1
# fi

xfs_growfs -m 90 $device

nr_inodes_per_dir=$((10 ** 6))
nr_procs=$(nproc)
iter_size=$((nr_inodes_per_dir / nr_procs))

nr_dirs=800

echo "Creating files"
for i in $(seq 399 $nr_dirs); do
	testdir=/mnt/testdir-${i}

	[[ -d $testdir ]] && { echo "Skipping $testdir"; continue; }

	mkdir $testdir

	echo -n "$testdir ... "

	offset=0

	while (( $offset < $nr_inodes_per_dir )); do
		start=$offset
		end=$((start + iter_size - 1))

		$popdir --dir $testdir --start=${start} --incr=1 \
			--end=${end} --file-pct 100 --format "%010d" &

		offset=$((start + iter_size))
	done

	wait

	echo "Done"

	# if (( $i <= 250 )); then
	# 	continue
	# fi

	# if (( $i % 5 != 0 )); then
	# 	continue
	# fi

	# echo "Unmounting $device"
	# umount $device
	# if [[ $? != 0 ]]; then
	# 	echo "Umount failed"
	# 	exit 1
	# fi

	# echo "Executing xfs_repair"
	# time xfs_repair -v $device

	# mount $device $mntpnt
	# if [[ $? != 0 ]]; then
	# 	echo "mount failed."
	# 	exit 1
	# fi
done
