#!/usr/bin/zsh -f

dev=/dev/sdb1
mntpnt=/root/junk/mnt/

umount $mntpnt > /dev/null 2>&1

echo "Creating filesystem"
mkfs.xfs -f $dev
if [[ $? != 0 ]]; then
	echo "Unable to create filesystem"
	exit 1
fi

echo "Mounting filesystem"
mount $dev $mntpnt
if [[ $? != 0 ]]; then
	echo "Unable to mount filesystem"
	exit 1
fi

dirs=(dir0 dir1 dir2)

echo "Creating directories, files and assigning project ids"
projid=32
for d in ${dirs[@]}; do
	dir_path=${mntpnt}/${d}

	mkdir $dir_path
	xfs_quota -x -c "project -cs -p $dir_path $projid" ${mntpnt}
	for i in $(seq 0 9); do
		touch $dir_path/file-${i}.bin
	done
	xfs_io -c "lsproj -R" $dir_path
	((projid = projid + 1))
done
