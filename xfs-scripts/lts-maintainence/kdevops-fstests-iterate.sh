#!/bin/bash

if (( $# != 4 )); then
	echo "Usage: $0 <kernel-version> <start-iteration> <end-iteration> <log-file>"
	exit 1
fi

kernel_version=$1
start_iteration=$2
end_iteration=$3
log=$4

expunges_dir=workflows/fstests/expunges/${kernel_version}/xfs/unassigned/

did_copy_results_fail()
{
	for l in $(grep -A 7 'PLAY RECAP' $log | tail -n 7); do
		echo $l | grep -q -i 'failed=1'
		[[ $? == 0 ]] && return 0
	done

	return 1
}

retry_copy()
{
	i=0
	while [[ 1 ]]; do
		((i = i + 1))
		echo "Copying results: Attempt: $i"
		ansible-playbook -i ./hosts --extra-vars \
				 @./extra_vars.yaml \
				 playbooks/fstests.yml \
				 --tags "copy_results"
		[[ $? == 0 ]] && return 0
	done

	return 1
}

git diff --exit-code > /dev/null 2>&1
if [[ $? == 1  ]]; then
	echo "Repository has uncommitted changes"
	exit 1
fi

for (( i = $start_iteration; i <= $end_iteration; i++ )); do
	echo "---------- Iteration: $i ----------"
	make fstests-baseline
	if [[ $? != 0 ]]; then
		did_copy_results_fail
		if [[ $? == 0 ]]; then
			retry_copy
		else
			echo "make fstests-baseline failed"
			exit 1
		fi
	fi

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
