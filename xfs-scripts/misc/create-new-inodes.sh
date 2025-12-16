#!/usr/bin/bash

mntpnt=/mnt/
testdir=/mnt/testdir

for i in $(seq 1 5000); do
	touch ${testdir}/${i}
done
