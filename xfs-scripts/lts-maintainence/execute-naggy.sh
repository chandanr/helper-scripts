#!/bin/bash

log_file=/root/naggy.log

source /root/.kdevops_fstests_setup

rm -rf $log_file

cd /var/lib/xfstests/

./gendisks.sh

mkfs.xfs -f /dev/loop16

seq 1 1000 | while read -r nr; do
	echo "---- $nr -----"

	/usr/local/sbin/perf record -m 256M -r 1 -c 1 -o /data/perf.data \
	     -e xfs:xfs_buf_lock \
	     -e xfs:xfs_buf_unlock \
	     -e xfs:xfs_buf_lock_done -g -a &

	perf_pid=$!

	echo "Perf pid = $perf_pid"

	# echo "Check on Perf"
        # ps -c $perf_pid

	./naggy-check.sh --section xfs_nocrc_512 -c 1 -f generic/299

	kill -2 $perf_pid
	wait $perf_pid

done 2>&1 | tee -a $log_file
