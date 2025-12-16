#!/bin/bash

if [[ $# != 3 ]]; then
	echo "Usage: ./$0 <device> <file to unlink> <sleep duration>"
	exit 1
fi

device=$1
testfile=$2
duration=$3

echo "Deleting file: $testfile"
unlink $testfile
# sleep $duration
umount $device

