#!/bin/bash

# ./kdevops-ci-execute.sh 5.4.225+ 54 1000 /tmp/prev_stats.txt
xunit_results=workflows/fstests/results/xunit_results.txt
gen_results_summary=./playbooks/python/workflows/fstests/gen_results_summary
results_dir=./workflows/fstests/results/
summary=/tmp/summary.log

declare -A xfs_nocrc xfs_nocrc_512 xfs_crc xfs_reflink xfs_reflink_1024 \
	xfs_reflink_normapbt xfs_logdev

declare -a tests

sections=(xfs_nocrc xfs_nocrc_512 xfs_crc xfs_reflink xfs_reflink_1024
	  xfs_reflink_normapbt xfs_logdev)

tests_ignore=(generic/475)

trap handle_sigint SIGINT
trap handle_sigusr1 SIGUSR1

handle_sigint()
{
	echo "Executing SIGINT trap: Iteration count = $iter_count"
	dump_test_run_stats
	exit 1
}

handle_sigusr1()
{
	echo "Executing SIGUSR1 trap: Iteration count = $iter_count"
	dump_test_run_stats
}

read_prev_stats()
{
	stats_file=$1
	found_section=0
	section=""

	while read -r line; do
		[[ -z $line ]] && continue

		echo $line | grep -iq section
		if [[ $? == 0 ]]; then
			section=$(echo $line | awk '{ print($2) }')
			found_section=1
			echo "Retrieving statistics for $section"
			continue
		fi

		if [[ $found_section == 0 ]]; then
			echo "Section not found; Exiting"
			exit 1
		fi
		
		test_name=$(echo $line | awk '{ split($1, a, ":"); print(a[1]); }')
		fail_count=$(echo $line | awk '{ print($5) }')

		case $section in
			"xfs_nocrc")
				((xfs_nocrc[$test_name] = ${xfs_nocrc[$test_name]} + $fail_count))
				;;
			"xfs_nocrc_512")
				((xfs_nocrc_512[$test_name] = ${xfs_nocrc_512[$test_name]} + $fail_count))
				;;
			"xfs_crc")
				((xfs_crc[$test_name] = ${xfs_crc[$test_name]} + $fail_count))
				;;
			"xfs_reflink")
				((xfs_reflink[$test_name] = ${xfs_reflink[$test_name]} + $fail_count))
				;;
			"xfs_reflink_1024")
				((xfs_reflink_1024[$test_name] = ${xfs_reflink_1024[$test_name]} + $fail_count))
				;;
			"xfs_reflink_normapbt")
				((xfs_reflink_normapbt[$test_name] = ${xfs_reflink_normapbt[$test_name]} + $fail_count))
				;;
			"xfs_logdev")
				((xfs_logdev[$test_name] = ${xfs_logdev[$test_name]} + $fail_count))
				;;
			*)
				echo "read_prev_stats: Invalid section $section"
				exit 1
				;;
		esac
		
	done < $stats_file

	dump_test_run_stats
}

dump_section_stats()
{
	local fail_count
	section=$1

	for test_case in ${tests[@]}; do
		fail_count=0
		case $section in
			"xfs_nocrc")
				if [[ ${xfs_nocrc[$test_case]} != "" ]]; then
					fail_count=${xfs_nocrc[$test_case]}
				fi
				;;

			"xfs_nocrc_512")
				if [[ ${xfs_nocrc_512[$test_case]} != "" ]]; then
					fail_count=${xfs_nocrc_512[$test_case]}
				fi
				;;

			"xfs_crc")
				if [[ ${xfs_crc[$test_case]} != "" ]]; then
					fail_count=${xfs_crc[$test_case]}
				fi
				;;

			"xfs_reflink")
				if [[ ${xfs_reflink[$test_case]} != "" ]]; then
					fail_count=${xfs_reflink[$test_case]}
				fi
				;;

			"xfs_reflink_1024")
				if [[ ${xfs_reflink_1024[$test_case]} != "" ]]; then
					fail_count=${xfs_reflink_1024[$test_case]}
				fi
				;;

			"xfs_reflink_normapbt")
				if [[ ${xfs_reflink_normapbt[$test_case]} != "" ]]; then
					fail_count=${xfs_reflink_normapbt[$test_case]}
				fi
				;;

			"xfs_logdev")
				if [[ ${xfs_logdev[$test_case]} != "" ]]; then
					fail_count=${xfs_logdev[$test_case]}
				fi
				;;

			*)
				echo "dump_section_stats: Invalid section: $section"
				exit 1
				;;
		esac

		echo -e "\t${test_case}: Fail count = $fail_count"
	done
}

dump_test_run_stats()
{
	for s in ${sections[@]}; do
		echo "section: $s"
		dump_section_stats $s
	done
}

update_section_stats()
{
	section=$1
	summary=$2

	while read -r line; do
		echo $line | grep -qi fail
		[[ $? != 0 ]] && continue

		test_name=$(echo $line | awk '{ print($1) }')
		case $section in
			"xfs_nocrc")
				((xfs_nocrc[$test_name] = ${xfs_nocrc[$test_name]} + 1))
				;;
			"xfs_nocrc_512")
				((xfs_nocrc_512[$test_name] = ${xfs_nocrc_512[$test_name]} + 1))
				;;
			"xfs_crc")
				((xfs_crc[$test_name] = ${xfs_crc[$test_name]} + 1))
				;;
			"xfs_reflink")
				((xfs_reflink[$test_name] = ${xfs_reflink[$test_name]} + 1))
				;;
			"xfs_reflink_1024")
				((xfs_reflink_1024[$test_name] = ${xfs_reflink_1024[$test_name]} + 1))
				;;
			"xfs_reflink_normapbt")
				((xfs_reflink_normapbt[$test_name] = ${xfs_reflink_normapbt[$test_name]} + 1))
				;;
			"xfs_logdev")
				((xfs_logdev[$test_name] = ${xfs_logdev[$test_name]} + 1))
				;;
			*)
				echo "update_section_stats: Invalid section $section"
				exit 1
				;;
		esac

	done < $summary
}

ignore_test()
{
	local t
	tc=$1

	for t in ${tests_ignore[@]}; do
		if [[ $t == $tc ]]; then
			return 0
		fi
	done

	return 1
}

if (( $# < 3 )); then
	echo "Usage: $0 <kernel version> <start iteration> <iteration count> <previous stats>"
	exit 1
fi

kernel_vers=$1
start_iter=$2
nr_iter=$3
prev_stats=$4

if [[ ! -z $prev_stats && -a $prev_stats ]]; then
	read_prev_stats $prev_stats
else
	echo "No previous stats to read"
fi

expunge_dir=./workflows/fstests/expunges/${kernel_vers}/xfs/unassigned/
for f in $(ls -1 $expunge_dir); do
	echo "Processing expunge directory: $f"
	while read -r line; do
		t=$(echo $line | awk -F '[# ]' '{print $1}')
		# echo "t=$t"
		ignore_test $t
		if [[ $? != 0 ]]; then
			tests+=(${t})
		else
			echo "Ignoring test $t"
		fi
	done < ${expunge_dir}/${f}
done

tests=($(echo "${tests[@]}" | tr ' ' '\n' | sort | uniq | tr '\n' ' '))
echo "---- Tests -----"

i=0
for t in ${tests[@]}; do
	((i = i + 1))
	echo "$i = $t"
done

make fstests
if [[ $? != 0 ]]; then
	echo "\'make fstests\' failed"
	exit 1
fi

for i in $(seq $start_iter $nr_iter); do
	echo "----- ${i}/${nr_iter} -----"
	iter_count=$i

	printf -v tlist "%s " "${tests[@]}"

	make fstests-baseline TESTS=\""$tlist"\"

	grep -iq failures $xunit_results
	[[ $? != 0 ]] && continue

	for s in ${sections[@]}; do
		section_results=${results_dir}/${kernel_vers}/${s}
		$gen_results_summary --results_file result.xml \
				     --print_section $section_results \
				     --verbose > $summary 2>/dev/null

		tail -n +3 $summary > $summary.tmp
		head -n -2 $summary.tmp > $summary

		update_section_stats $s $summary
	done

	if (( $i % 10 == 0 )); then
		dump_test_run_stats
	fi
done

dump_test_run_stats
