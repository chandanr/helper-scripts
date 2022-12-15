#!/bin/bash

# TODO: Test SIGINT
trap "dump_test_run_stats; exit 0" SIGINT 

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
				echo "Invalid test case"
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
				echo "Invalid case"
				exit 1
				;;
		esac

	done < $summary
}

if [[ $# != 2 ]]; then
	echo "Usage: $0 <kernel version>  <iteration count>"
	exit 1
fi
kernel_vers=$1
nr_iter=$2

make fstests
if [[ $? != 0 ]]; then
	echo "\'make fstests\' failed"
	exit 1
fi

for i in $(seq 1 $nr_iter); do
	echo "----- $i -----"
	make fstests-baseline

	grep -iq failures $xunit_results
	[[ $? != 0 ]] && continue

	for s in ${sections[@]}; do
		# echo "s = $s"
		# s=$(echo $s | sed s/_/-/g)
		section_results=${results_dir}/${kernel_vers}/${s}
		# echo "Processing $section_results ..."
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
