#!/usr/bin/zsh -f

# Tracepoints
# xfs:xfs_iomap_alloc
# xfs:xfs_iomap_found

device=/dev/loop0
mntpnt=/mnt/
srcfile=${mntpnt}/srcfile
destfile=${mntpnt}/destfile

umount $device > /dev/null 2>&1

echo "Creating fs"
mkfs.xfs -f -m reflink=1 $device &> /dev/null
if [[ $? != 0 ]]; then
	echo "mkfs.xfs failed.\n"
	exit 1
fi

echo "Mounting fs"
mount $device $mntpnt > /dev/null 2>&1
if [[ $? != 0 ]]; then
	echo "mount failed.\n"
	exit 1
fi

bsize=$(stat -f -c "%s" $mntpnt)

echo "Create shared extent"
xfs_io -f -c "pwrite $((0 * $bsize)) $((5 * $bsize))" $srcfile &> /dev/null
xfs_io -f -c "reflink $srcfile 0 $((36 * $bsize)) $((5 * $bsize))" $destfile &> /dev/null
filefrag -b${bsize} -v $destfile

echo "Buffered write on hole"
xfs_io -f -c "pwrite -b $((4 * $bsize)) $((32 * $bsize)) $((4 * $bsize))" $destfile &> /dev/null

echo "Buffered write on shared extent"
xfs_io -f -c "pwrite -b $((5 * $bsize)) $((36 * $bsize)) $((5 * $bsize))" $destfile &> /dev/null

sync

filefrag -b${bsize} -v $destfile
