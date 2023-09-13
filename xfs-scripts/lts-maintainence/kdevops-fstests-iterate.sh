#!/bin/bash

if (( $# < 5 )); then
	echo "Usage: $0 <kernel-version> <start-iteration> <end-iteration> <log-file> <stop-iteration-file> [test list]"
	exit 1
fi

kernel_version=$1
start_iteration=$2
end_iteration=$3
log=$4
stop_iter_file=$5

test_list=""
if [[ $# == 6 ]]; then
	test_list=" TESTS=\"$6\""
fi


expunges_dir=$(realpath workflows/fstests/expunges/${kernel_version}/xfs/unassigned/)

stop_test()
{
	if [[ -a $stop_iter_file ]]; then
		echo "Stop iteration file $stop_iter_file found; Exiting"
		exit 0
	fi
}

git diff --exit-code > /dev/null 2>&1
if [[ $? == 1  ]]; then
	echo "Repository has uncommitted changes"
	exit 1
fi

if [[ -a $log ]]; then
	echo "Backing up $log"
	mv $log ${log}.backup
fi

for (( i = $start_iteration; i <= $end_iteration; i++ )); do
	stop_test

	echo "---------- Iteration: $i ----------"

	cmd="make fstests-baseline"
	if [[ -n $test_list ]]; then
		cmd=${cmd}${test_list}
	fi

	eval $cmd
	if [[ $? != 0 ]]; then
		echo "make fstests-baseline failed"
		exit 1
	fi

	./scripts/workflows/fstests/copy-results.sh
	if [[ $? != 0 ]]; then
		echo "copy_results.sh failed"
		exit 1
	fi

	git commit -s -m "copy_results.sh: Iteration $i"

	./scripts/workflows/fstests/find-common-failures.sh -l $expunges_dir
	./scripts/workflows/fstests/remove-common-failures.sh $expunges_dir

	echo "--------------------------------------------------------------------------------"
	git diff
	echo "--------------------------------------------------------------------------------"

	# Check untracked files
	for f in $(git ls-files --others --exclude-standard $expunges_dir); do
		# Skip zero length files
		[[ ! -s $f ]] && continue

		echo "Adding untracked file $f"
		git add $f
	done

	git diff --cached --exit-code > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		git commit -s -m "Committing untracked files"
	fi

	for f in $(git diff --name-only); do
		if [[ -s $f ]]; then
			echo "Add new failures in $f"
			git add $f
		else
			echo "Removing zero sized file: $f"
			git rm $f
		fi
	done

	git diff --cached --exit-code > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		git commit -s -m "Committing new test failures"
	fi
done 2>&1 | tee -a $log
