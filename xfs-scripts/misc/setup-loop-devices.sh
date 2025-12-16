#!/usr/bin/bash

setup_log_device=false
if [[ $# -ge 1 && $1 == "-l" ]]; then
	setup_log_device=true
fi

mount -t tmpfs -o size=1G,nr_inodes=10k,mode=0700 tmpfs /root/junk/disk-images/
mount -o remount,size=50G /root/junk/disk-images/
if [[ $? != 0  ]]; then
	echo "Mounting tmpfs failed"
	exit 1
fi

disk0=/root/junk/disk-images/disk-0.img
disk1=/root/junk/disk-images/disk-1.img

fallocate -l 20G $disk0
if [[ $? != 0  ]]; then
	echo "Fallocating $disk0 failed"
	exit 1
fi

fallocate -l 20G $disk1
if [[ $? != 0  ]]; then
	echo "Fallocating $disk1 failed"
	exit 1
fi

losetup -a | grep -i loop
if [[ $? == 0 ]]; then
	echo "Loop devices already setup."
	exit 1
fi

for i in $(seq 0 1); do
	losetup /dev/loop${i} /root/junk/disk-images/disk-${i}.img
done

if [[ $setup_log_device == true ]]; then
	losetup /dev/loop2 /root/mnt/disk-images/20g-0.img
	losetup /dev/loop3 /root/mnt/disk-images/20g-1.img
fi

losetup -a
