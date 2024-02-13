#!/bin/bash

usage()
{
	echo "Usage: $0 <Test directory 1 results> <Test directory 2 results> <graphs_dir>"
	exit 1
}

if [[ $# != 3 ]]; then
	usage
fi

test_results_dir1=$1
test_results_dir2=$2
graphs_dir=$3

[[ ! -d $test_results_dir1 ]] && usage
[[ ! -d $test_results_dir2 ]] && usage

kernel_version_1=$(basename $test_results_dir1)
kernel_version_2=$(basename $test_results_dir2)

for d in $(ls -1 ${test_results_dir1}); do
	dir1=${test_results_dir1}/${d}
	dir2=${test_results_dir2}/${d}

	[[ ! -d $dir1 ]] && continue
	[[ ! -d $dir2 ]] && continue

	echo "Processing $d"

	check1=${dir1}/check.time
	check2=${dir2}/check.time

	rm -f /tmp/test-list.log

	rm -f /tmp/first.log
	rm -f /tmp/second.log
	rm -f /tmp/merge.log

	cat $check1 | while read -r line; do
		echo "$line" | awk '{ print $1; }' >> /tmp/test-list.log
	done

	cat $check2 | while read -r line; do
		echo "$line" | awk '{ print $1; }' >> /tmp/test-list.log
	done

	sort /tmp/test-list.log | uniq > /tmp/tmp-list.log
	mv /tmp/tmp-list.log /tmp/test-list.log

	i=0
	cat /tmp/test-list.log | while read -r test_nr; do
		check_time1=$(grep $test_nr $check1)
		[[ $? != 0 ]] && continue

		check_time2=$(grep $test_nr $check2)
		[[ $? != 0 ]] && continue

		check_time1=$(echo $check_time1 | awk '{ print $2; }')
		check_time2=$(echo $check_time2 | awk '{ print $2; }')

		echo "$i $test_nr $check_time1 $check_time2" >> /tmp/merge.log
		((i = i + 1))
	done

	done

	gnuplot <<- EOF
	set terminal pngcairo enhanced size 1916,1012
	set output "${graphs_dir}/${d}-graph.png"

	set xlabel "Test"
	set ylabel "Time"

	set xtic auto
	set ytic auto

	set title "$d"
	plot "/tmp/merge.log" using 1:3 title "${kernel_version_1}" with lines, "/tmp/merge.log" using 1:4 title "${kernel_version_2}" with lines
	EOF
done
