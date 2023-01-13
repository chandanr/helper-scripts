#!/bin/bash

# ./kdevops-ci-execute.sh 5.4.225+ 54 1000 /tmp/prev_stats.txt
trap "echo \"Executing SIGINT trap\"; dump_test_run_stats; exit 1" SIGINT
trap "echo \"Executing SIGUSR1 trap\"; dump_test_run_stats;" SIGUSR1

xunit_results=workflows/fstests/results/xunit_results.txt
gen_results_summary=./playbooks/python/workflows/fstests/gen_results_summary
results_dir=./workflows/fstests/results/
summary=/tmp/summary.log

declare -A xfs_nocrc xfs_nocrc_512 xfs_crc xfs_reflink xfs_reflink_1024 \
	xfs_reflink_normapbt xfs_logdev

sections=(xfs_nocrc xfs_nocrc_512 xfs_crc xfs_reflink xfs_reflink_1024
	  xfs_reflink_normapbt xfs_logdev)

test_cases=(generic/019 generic/388 generic/455 generic/457 generic/475
	    generic/482 generic/646 generic/648 xfs/057)

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
	section=$1

	for test_case in ${test_cases[@]}; do
		case $section in
			"xfs_nocrc")
				if [[ ${xfs_nocrc[$test_case]} != "" ]]; then
					echo -e "\t${test_case}: Fail count = ${xfs_nocrc[$test_case]}"
				fi
				;;

			"xfs_nocrc_512")
				if [[ ${xfs_nocrc_512[$test_case]} != "" ]]; then
					echo -e "\t${test_case}: Fail count = ${xfs_nocrc_512[$test_case]}"
				fi
				;;

			"xfs_crc")
				if [[ ${xfs_crc[$test_case]} != "" ]]; then
					echo -e "\t${test_case}: Fail count = ${xfs_crc[$test_case]}"
				fi
				;;

			"xfs_reflink")
				if [[ ${xfs_reflink[$test_case]} != "" ]]; then
					echo -e "\t${test_case}: Fail count = ${xfs_reflink[$test_case]}"
				fi
				;;

			"xfs_reflink_1024")
				if [[ ${xfs_reflink_1024[$test_case]} != "" ]]; then
					echo -e "\t${test_case}: Fail count = ${xfs_reflink_1024[$test_case]}"
				fi
				;;

			"xfs_reflink_normapbt")
				if [[ ${xfs_reflink_normapbt[$test_case]} != "" ]]; then
					echo -e "\t${test_case}: Fail count = ${xfs_reflink_normapbt[$test_case]}"
				fi
				;;

			"xfs_logdev")
				if [[ ${xfs_logdev[$test_case]} != "" ]]; then
					echo -e "\t${test_case}: Fail count = ${xfs_logdev[$test_case]}"
				fi
				;;

			*)
				echo "dump_section_stats: Invalid section: $section"
				exit 1
				;;
		esac
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

if (( $# < 3 )); then
	echo "Usage: $0 <kernel version> <start iteration> <iteration count> <previous stats>"
	exit 1
fi

kernel_vers=$1
start_iter=$2
nr_iter=$3
prev_stats=$4

if [[ ! -z $prev_stats && -a $prev_stats ]]; then
	read_prev_stats /tmp/prev_stats.txt
else
	echo "No previous stats to read"
fi

make fstests
if [[ $? != 0 ]]; then
	echo "\'make fstests\' failed"
	exit 1
fi

for i in $(seq $start_iter $nr_iter); do
	echo "----- ${i}/${nr_iter} -----"
	make fstests-baseline

	grep -iq failures $xunit_results
	[[ $? != 0 ]] && continue

	for s in ${sections[@]}; do
		section_results=${results_dir}/${kernel_vers}/${s}
		$gen_results_summary --results_file result.xml --print_section \
				     $section_results > $summary 2>/dev/null

		tail -n +3 $summary > $summary.tmp
		head -n -2 $summary.tmp > $summary

		update_section_stats $s $summary
	done

	if (( $i % 10 == 0 )); then
		dump_test_run_stats
	fi
done

dump_test_run_stats
