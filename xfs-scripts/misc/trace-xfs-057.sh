#!/bin/bash

set -euo pipefail

log_file=/data/naggy.log
linux_dir=/data/xfs-linux/
xfstests_dir=/var/lib/xfstests/
perf_bin_file=/data/perf.data

source /root/.kdevops_fstests_setup
source /root/.bashrc
rm -rf $log_file

return_success=$(cat << EOF
true
EOF
)

rm -rf ${perf_bin_file} ${perf_bin_file}.old

xfs_repair=/usr/local/sbin/xfs_repair
file $xfs_repair | grep -i -q ELF
if [[ $? == 0 ]]; then
	mv $xfs_repair ${xfs_repair}_backup
	echo $return_success > $xfs_repair
	chmod a+x $xfs_repair
fi

xfs_scrub=/usr/local/usr/sbin/xfs_scrub
file $xfs_scrub | grep -i -q ELF
if [[ $? == 0 ]]; then
	mv $xfs_scrub ${xfs_scrub}_backup
	echo $return_success > $xfs_scrub
	chmod a+x $xfs_scrub
fi

xfs_spaceman=/usr/local/usr/sbin/xfs_spaceman
file $xfs_spaceman  | grep -i -q ELF
if [[ $? == 0 ]]; then
	mv $xfs_spaceman ${xfs_spaceman}_backup
	echo $return_success > $xfs_spaceman
	chmod a+x $xfs_spaceman
fi

dnf '--enablerepo=*' builddep -y perf | tee -a $log_file
dnf install -y libunwind-devel | tee -a $log_file

cd $linux_dir
echo "--- Building and installing perf ----" | tee -a $log_file
make -C tools/perf | tee -a $log_file
rm -rf /sbin/perf
cp tools/perf/perf /sbin/

section=$(hostname -s | \
		  awk '{ gsub("chanbabu[A-Za-z0-9]+-", "", $0); print }' | \
		  awk '{ gsub("-", "_", $0); print }')
echo "section = $section" | tee -a $log_file

cd $xfstests_dir
seq 0 2 | while read -r nr; do
	./gendisks.sh -d -m
done | tee -a $log_file

echo "---- losetup ----"
losetup -a  | tee -a $log_file

kill_long_running_perf()
{
	perf_pid=$1

	while [ 1 ]; do
		umount_pid=$(pidof umount)
		if [[ $? != 0 ]]; then
			sleep 10s
			continue
		fi

		etimes=$(ps -h -o etimes $umount_pid)
		max_duration=20

		umount_pid=$(pidof umount)
		if [[ $? != 0 ]]; then
			sleep 10s
			continue
		fi

		if (( $etimes >= $max_duration )); then
			echo "Umount has been running for more than $max_duration"
			kill -2 $perf_pid
			wait $perf_pid
			return
		else
			sleep 2s
			continue
		fi
	done
}

i=0
while [ 1 ]; do
	(( i = i + 1 ));
	echo "---- $i ----"

	rm -rf ${perf_bin_file} ${perf_bin_file}.old

	perf record -m 256M -r 1 -c 1 -o $perf_bin_file -e 'xfs:*' -g -a &
	perf_pid=$!
	echo "Perf pid = $perf_pid"

	kill_long_running_perf $perf_pid &
	long_running_perf_pid=$!
	echo "Long running perf pid = $long_running_perf_pid"

	./naggy-check.sh --section $section -c 1 -f  xfs/057

	echo "killing long_running_perf_pid $long_running_perf_pid"
	kill -9 $long_running_perf_pid
	wait $long_running_perf_pid

	echo "Killing perf $perf_pid"
	kill -2 $perf_pid
	wait $perf_pid

done 2>&1 | tee -a $log_file
