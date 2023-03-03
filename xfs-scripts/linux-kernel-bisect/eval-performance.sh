#!/bin/bash

# 1. Delete numbered directory entries from $runlogs
# 2. Delete bisect.log
# 3. Enable bisect.service
# [Unit]
# Description=chandan-git-bisect
# After=data.mount
# StartLimitIntervalSec=0

# [Service]
# Type=simple
# Restart=no
# User=root
# ExecStart=/data/automate/driver.sh

# [Install]
# WantedBy=multi-user.target


build_and_boot_kernel=/data/automate/build-and-boot-kernel.sh
datadir=/data/
kerneldir=${datadir}/linux-v5.19/
runlogs=${datadir}/runlogs/
nr_samples=5
target_iops=2440

# echo "Inside $0" > /tmp/file.log

cd $kerneldir
commit=$(git log -1 --oneline | awk '{print($1);}')
echo "------- commit: $commit ------"

iter=$(find $runlogs -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -g | tail -1)
if [[ -z $iter ]]; then
    iter=1
else
    ((iter = iter + 1))
fi

bisect_logs=${runlogs}/${iter}
mkdir $bisect_logs

create_fs_on_striped_lvm=${datadir}/create-fs-on-striped-lvm.sh

for i in $(seq 1 $nr_samples); do
    fio_log=${bisect_logs}/${i}.log
    
    echo "----- $i -----";

    echo "Creating striped LVM"
    ${create_fs_on_striped_lvm}
    if [[ $? != 0 ]]; then
	echo "Unable to create fs on LVM"
	exit 1
    fi
    

    echo "Execute fio"
    fio --eta=never --output=${fio_log} -name fio.test --directory=/test \
	--rw=randwrite --bs=4k --size=4G --ioengine=libaio --iodepth=16 \
	--direct=1 --time_based=1 --runtime=15m --randrepeat=1 --gtod_reduce=1 \
	--group_reporting=1 --numjobs=64;

    cp $fio_log /tmp/fio.log
    echo "------- commit: $commit ------" > $fio_log
    cat /tmp/fio.log >> $fio_log
done


count=0;
sum=0;

for iops in $(grep 'write: IOPS=' ${bisect_logs}/[0-9]*.log | awk -F '[ =,]' '{ iops = $5; gsub("k", "", iops); printf("%d\n", iops);}'); do
    echo "iops = $iops";
    ((sum = sum + iops));
    ((count = count + 1));
done

echo "sum = $sum";

((avg = sum / count));

echo "avg = $avg"

# Compute standard deviation
sum_of_squares=0
for iops in $(grep 'write: IOPS=' ${bisect_logs}/[0-9]*.log | awk -F '[ =,]' '{ iops = $5; gsub("k", "", iops); printf("%d\n", iops);}'); do
    if [[ $avg < $iops  ]]; then
	((distance = iops - avg))
    else
	((distance = avg - iops))
    fi

    ((distance = distance ** 2))
    
    ((sum_of_squares = sum_of_squares + distance))
done

((std = sum_of_squares / nr_samples))

echo "Standard deviation = $std"

if (( $avg >= $target_iops )); then
    perf=good-perf
else
    perf=bad-perf
fi

echo "perf = $perf"

cd $kerneldir

git bisect $perf
if [[ $? != 0 ]]; then
    echo "Git bisect failed"
    systemctl stop bisect.service
    exit 1
fi

exit 0
