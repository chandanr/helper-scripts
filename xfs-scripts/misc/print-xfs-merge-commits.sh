#!/bin/bash

if [[ $# != 1 ]]; then
	echo "Usage: ./$0 <kernel directory>"
	exit 1
fi

cd $1

for major_rev in $(seq 5 6); do
	start=1
	[[ $major_rev == 5 ]] && start=16

	end=19
	[[ $major_rev == 6 ]] && end=12

	echo "--- Kernel version: $major_rev ---"
	for minor_rev in $(seq $start $end); do
		prev_minor_rev=$(($minor_rev - 1))
		git --no-pager log --reverse --merges \
		    v${major_rev}.${prev_minor_rev}..v${major_rev}.${minor_rev}-rc1 \
		    -- fs/xfs
	done
done
