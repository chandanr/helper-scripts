#!/usr/bin/zsh -f

dev=/dev/loop0
mntpnt=/mnt/
testfile=${mntpnt}/testfile
punch_prog=/root/repos/xfstests-dev/src/punch-alternating

umount $dev > /dev/null 2>&1

xfs_db_tests()
{
	for nrext64 in 0 1; do
		if [[ $nrext64 == 0 ]]; then
			test_type="Disable"
		else
			test_type="Enable"
		fi

		print "* $test_type nrext64 option"

		mkfs.xfs -K -f -i nrext64=${nrext64} $dev > /dev/null 2>&1 || { print "mkfs.xfs failed"; exit 1 }
		mount $dev $mntpnt || { print "mount failed."; exit 1 }

		print "Creating testfile"
		xfs_io -f -c "pwrite 0 32M" $testfile > /dev/null 2>&1
		sync
		print "Punching out alternate blocks"
		$punch_prog $testfile

		print "Inserting xattrs"
		for i in $(seq 1 1000); do
			attr="$(printf "trusted.%0247d" $i)"
			setfattr -n "$attr" $testfile
			[[ $? != 0 ]] && break
		done

		testino=$(stat -c "%i" $testfile)
		umount $mntpnt

		echo "--- xfs_db output ---"
		xfs_db_output=$(xfs_db -c "inode $testino" -c print $dev | grep -i nextents)
		echo $xfs_db_output

		if [[ $nrext64 == 0 ]]; then
			echo $xfs_db_output | grep -i -q nextents64
			[[ $? == 0 ]] && { echo "64-bit counter incorrectly activated"; exit 1 }
		else
			val=$(echo $xfs_db_output | grep -i nextents16)
			val=${val##core.nextents16 = }
			[[ $val != 0 ]] && { echo "16-bit counter incorrectly activated"; exit 1 }
		fi
		print "\n"
	done
}

mkfs_tests()
{
	mkfs_v4=("-m crc=0 -b size=1k"
		 "-m crc=0 -b size=4k"
		 "-m crc=0 -b size=512")

	mkfs_v5=("-m rmapbt=0,reflink=0 -b size=1k"
		 "-m rmapbt=1,reflink=1 -b size=1k"
		 "-m rmapbt=0,reflink=0 -b size=4k"
		 "-m rmapbt=1,reflink=1 -b size=4k")

	print "* Try to create v4 fs with nrext64 enabled "
	for opts in $mkfs_v4; do
		mkfs.xfs -f ${(ps: :)opts} -i nrext64=1 $dev > /dev/null 2>&1
		if [[ $? == 0 ]]; then
			echo "Error: V4 filesystem created with nrext64 option enabled"
			exit 1
		fi
	done

	print "* Try to create v5 fs with nrext64 disabled"
	for opts in $mkfs_v5; do
		mkfs.xfs -f ${(ps: :)opts} -i nrext64=0 $dev > /dev/null 2>&1
		if [[ $? != 0 ]]; then
			echo "Error: V5 filesystem creation failed with nrext64 option disabled"
			exit 1
		fi
	done

	print "* Try to create v5 fs with nrext64 enabled"
	for opts in $mkfs_v5; do
		mkfs.xfs -f ${(ps: :)opts} -i nrext64=1 $dev > /dev/null 2>&1
		if [[ $? != 0 ]]; then
			echo "Error: V5 filesystem creation failed with nrext64 option enabled"
			exit 1
		fi
	done
}

mount_test_patched_kernel()
{
	local xfsprogs_patched=$1

	mkfs_v4=("-m crc=0 -b size=1k"
		 "-m crc=0 -b size=4k"
		 "-m crc=0 -b size=512")

	mkfs_v5=("-m rmapbt=0,reflink=0 -b size=1k"
		 "-m rmapbt=1,reflink=1 -b size=1k"
		 "-m rmapbt=0,reflink=0 -b size=4k"
		 "-m rmapbt=1,reflink=1 -b size=4k")

	case $xfsprogs_patched in
		yes)
			echo "Patched xfsprogs; Patched kernel: V4 fs"
			for opt in $mkfs_v4; do
				umount $dev > /dev/null 2>&1
				mkfs.xfs -K -f ${(ps: :)opt} $dev > /dev/null 2>&1 || { print "mkfs.xfs failed"; exit 1 }
				mount $dev $mntpnt
				if [[ $? != 0 ]]; then
					echo "Mount failed"
					exit 1
				fi
			done

			echo "Patched xfsprogs; Patched kernel: V5 fs; nrext64 disabled"
			for opt in $mkfs_v5; do
				umount $dev > /dev/null 2>&1
				mkfs.xfs -K -f -i nrext64=0 ${(ps: :)opt} $dev > /dev/null 2>&1 || { print "mkfs.xfs failed"; exit 1 }
				mount $dev $mntpnt
				if [[ $? != 0 ]]; then
					echo "Mount failed"
					exit 1
				fi
			done

			echo "Patched xfsprogs; Patched kernel: V5 fs; nrext64 enabled"
			for opt in $mkfs_v5; do
				umount $dev > /dev/null 2>&1
				mkfs.xfs -K -f -i nrext64=1 ${(ps: :)opt} $dev > /dev/null 2>&1 || { print "mkfs.xfs failed"; exit 1 }
				mount $dev $mntpnt
				if [[ $? != 0 ]]; then
					echo "Mount failed"
					exit 1
				fi
			done
			;;
		no)
			echo "Unpatched xfsprogs; Patched kernel: V4 fs"
			for opt in $mkfs_v4; do
				umount $dev > /dev/null 2>&1
				mkfs.xfs -K -f ${(ps: :)opt} $dev > /dev/null 2>&1 || { print "mkfs.xfs failed"; exit 1 }
				mount $dev $mntpnt
				if [[ $? != 0 ]]; then
					echo "Mount failed"
					exit 1
				fi
			done

			echo "Unpatched xfsprogs; Patched kernel: V5 fs; nrext64 disabled"
			for opt in $mkfs_v5; do
				umount $dev > /dev/null 2>&1
				mkfs.xfs -K -f ${(ps: :)opt} $dev > /dev/null 2>&1 || { print "mkfs.xfs failed"; exit 1 }
				mount $dev $mntpnt
				if [[ $? != 0 ]]; then
					echo "Mount failed"
					exit 1
				fi
			done
			;;
		*)
			echo "Invalid value provided for \$xfsprogs_patched argument"
			exit 1
	esac
}

mount_test_unpatched_kernel()
{
	local xfsprogs_patched=$1

	mkfs_v4=("-m crc=0 -b size=1k"
		 "-m crc=0 -b size=4k"
		 "-m crc=0 -b size=512")

	mkfs_v5=("-m rmapbt=0,reflink=0 -b size=1k"
		 "-m rmapbt=1,reflink=1 -b size=1k"
		 "-m rmapbt=0,reflink=0 -b size=4k"
		 "-m rmapbt=1,reflink=1 -b size=4k")

	case $xfsprogs_patched in
		yes)
			echo "Patched xfsprogs; Unpatched kernel: V4 fs"
			for opt in $mkfs_v4; do
				umount $dev > /dev/null 2>&1
				mkfs.xfs -K -f ${(ps: :)opt} $dev > /dev/null 2>&1 || { print "mkfs.xfs failed"; exit 1 }
				mount $dev $mntpnt
				if [[ $? != 0 ]]; then
					echo "Mount failed"
					exit 1
				fi
			done

			echo "Patched xfsprogs; Unpatched kernel: V5 fs; nrext64 disabled"
			for opt in $mkfs_v5; do
				umount $dev > /dev/null 2>&1
				mkfs.xfs -K -f -i nrext64=0 ${(ps: :)opt} $dev > /dev/null 2>&1 || { print "mkfs.xfs failed"; exit 1 }
				mount $dev $mntpnt
				if [[ $? != 0 ]]; then
					echo "Mount failed"
					exit 1
				fi
			done

			echo "Patched xfsprogs; Unpatched kernel: V5 fs; nrext64 enabled"
			for opt in $mkfs_v5; do
				umount $dev > /dev/null 2>&1
				mkfs.xfs -K -f -i nrext64=1 ${(ps: :)opt} $dev > /dev/null 2>&1 || { print "mkfs.xfs failed"; exit 1 }
				mount $dev $mntpnt > /dev/null 2>&1
				if [[ $? == 0 ]]; then
					echo "Mount succeded; should have failed"
					exit 1
				fi
			done
			;;

		*)
			echo "Invalid value provided for \$xfsprogs_patched argument"
			exit 1
	esac
}

if [[ $ARGC != 2 ]]; then
	echo "Usage: $0 <kernel-patched-status> <xfsprogs-patched-status>"
	exit 1
fi

kernel_patched=${argv[1]}
xfsprogs_patched=${argv[2]}
# echo "xfsprogs_patched = $xfsprogs_patched"

if [[ $kernel_patched == "yes" && $xfsprogs_patched == "yes" ]]; then
	xfs_db_tests
fi

if [[ $xfsprogs_patched == "yes" ]]; then
	mkfs_tests
fi

if [[ $kernel_patched == "yes" ]]; then
	mount_test_patched_kernel $xfsprogs_patched
else
	mount_test_unpatched_kernel $xfsprogs_patched
fi
