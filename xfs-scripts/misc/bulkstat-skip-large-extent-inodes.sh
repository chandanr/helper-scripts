#!/usr/bin/zsh -f

dev=/dev/loop0
mntpnt=/mnt/
punch_alternate=/root/repos/xfstests-dev/src/punch-alternating
testfile=${mntpnt}/testfile
testdir=${mntpnt}/testdir

umount $dev > /dev/null 2>&1

mkfs.xfs -f -i nrext64=1 $dev
if [[ $? != 0 ]]; then
	echo "Unable to mkfs.xfs $dev"
	exit 1
fi

mount $dev $mntpnt
if [[ $? != 0 ]]; then
	echo "Unable to mount $dev"
	exit 1
fi

bs=$(stat -f -c "%s" $mntpnt)
fsize=$(($bs * 40))

xfs_io -f -c "pwrite 0 $fsize" $testfile
sync
$punch_alternate $testfile

testino=$(stat -c "%i" $testfile)
echo "\$testino = $testino"

nextents=$(xfs_io -c stat $testfile | grep -w "nextents")
echo "\$testfile has $nextents extents"

mkdir $testdir
for i in $(seq 1 10); do
	touch ${testdir}/${i}
done

devshortform=${dev##/dev/}
echo 1 > /sys/fs/xfs/${devshortform}/errortag/reduce_max_iextents

cat /sys/fs/xfs/${devshortform}/errortag/reduce_max_iextents

echo "Executing bstat"
/root/repos/xfstests-dev/src/bstat $mntpnt

# umount $mntpnt
