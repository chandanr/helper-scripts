#!/bin/bash

if [[ $# != 3 ]]; then
    echo "Usage: $0 <bpf log> <log files directory> <dio length filter>"
    exit 1
fi

bpf_trace_log=$1
log_files_dir=$2
dio_len_filter=$3

rm -rf $log_files_dir
mkdir $log_files_dir

# found_ino=0
for ino in $(cat $bpf_trace_log | awk '{print($9)}' | awk -F ';' '{print($1)}' | sort | uniq); do
    # [[ $found_ino != 0 ]] && continue
    # found_ino=1

    echo "Processing inode $ino"
    ( while read -r line; do
	echo $line | grep -iq "inode = ${ino};"
	[[ $? != 0 ]] && continue

	dio_list_len=$(echo $line | awk '{print($12)}')
	if (( $dio_list_len > $dio_len_filter )); then
	    # echo "Skipping $dio_list_len"
	    continue
	fi


	ts=$(echo $line | awk '{print($6)}' | awk -F ';' '{print($1)}')
	echo "$ts $dio_list_len" >> $log_files_dir/inode-${ino}.txt
      done < $bpf_trace_log ) &
done

wait
