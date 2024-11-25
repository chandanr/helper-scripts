#!/bin/bash

# Requires the following patch to xfsprogs
# 
# modified   db/write.c
# @@ -612,7 +612,7 @@ convert_arg(
#          }
# 
#          /* handle decimal / hexadecimal integers */
# -        val = strtoll(arg, &endp, 0);
# +        val = strtoull(arg, &endp, 0);
#          /* return if not a clean number */
#          if (*endp != '\0')
#                  return NULL;
xfs_db=~/repos/xfsprogs-dev/db/xfs_db

dev=/dev/loop0
mntpnt=/mnt/
testdir=${mntpnt}/testdir

umount $dev > /dev/null 2>&1

mkfs.xfs -f -i sparse=0 -m finobt=0 $dev
if [[ $? != 0 ]]; then
	echo "Unable to mkfs.xfs $dev"
	exit 1
fi

mount $dev $mntpnt
if [[ $? != 0 ]]; then
	echo "Unable to mount $dev"
	exit 1
fi

echo "Create $testdir and test files"
mkdir $testdir
testdir_ino=$(stat -c '%i' $testdir)
echo "testdir_ino = $testdir_ino"

seq 1 20 | while read -r f; do
	touch ${testdir}/testfile-${f}.bin
done

ino=$(stat -c "%i" ${testdir}/testfile-1.bin)
echo "Marking inode $ino as free"

echo "Unmount filesystem"
umount $dev

start_ino=$(${xfs_db} \
		    -x -c 'fsblock 3'  \
		    -c 'type inobt' \
		    -c 'p recs[1].startino' $dev | awk -F '=' '{ print $2 }')
echo "Start inode number = $start_ino"
ino_offset=$(($ino - $start_ino))
echo "ino_offset = $ino_offset"

orig_free_map=$(${xfs_db} \
			-x -c 'fsblock 3'  \
			-c 'type inobt' \
			-c 'p recs[1].free' $dev | awk -F '=' '{ print $2 }')
echo "Orig free_map = $orig_free_map"

new_free_map=$(echo $orig_free_map | awk '{ printf("%d", strtonum($1)); }')
new_free_map=$(($new_free_map | $((1 << $ino_offset)) ))
new_free_map=$(echo $new_free_map | awk '{ printf("0x%x", strtonum($1)); }')
echo "New free_map = $new_free_map"

orig_freecount=$(${xfs_db} \
			 -x -c 'fsblock 3'  \
			 -c 'type inobt' \
			 -c 'p recs[1].freecount' $dev | awk -F '=' '{ print $2 }')
echo "Orig Freecount = $orig_freecount"
new_freecount=$(echo $orig_freecount | awk '{ printf("%d", strtonum($1)); }')
new_freecount=$(($new_freecount + 1))
echo "New free count = $new_freecount"

orig_agi_freecount=$(${xfs_db} \
			     -x \
			     -c 'agi 0' \
			    -c 'p freecount' $dev | awk -F '=' '{ print $2 }')
new_agi_freecount=$(($orig_agi_freecount + 1))
echo "orig_agi_freecount = $orig_agi_freecount"
echo "new_agi_freecount = $new_agi_freecount"


orig_sb_ifree=$(${xfs_db} \
			-x \
			-c 'sb 0' \
			-c 'p ifree' $dev | awk -F '=' '{ print $2 }')
new_sb_ifree=$(($orig_sb_ifree + 1))
echo "orig_sb_ifree = $orig_sb_ifree"
echo "new_sb_ifree = $new_sb_ifree"


${xfs_db} \
	-x -c 'fsblock 3'  \
	-c 'type inobt' \
	-c "write -d recs[1].free $new_free_map " $dev

${xfs_db} \
	-x -c 'fsblock 3'  \
	-c 'type inobt' \
	-c "write -d recs[1].freecount $new_freecount " $dev


${xfs_db} \
	-x \
	-c 'agi 0' \
	-c "write -d freecount $new_agi_freecount" $dev

${xfs_db} \
	-x \
	-c 'sb 0' \
	-c "write -d ifree $new_sb_ifree" $dev
