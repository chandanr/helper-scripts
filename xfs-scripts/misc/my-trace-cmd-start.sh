#!/bin/bash

mkfs.xfs -f /dev/loop1

trace-cmd start -p function -l xfs_mountfs --func-stack

mount /dev/loop1 /mnt/

trace-cmd stop

trace-cmd extract -o file.dat

trace-cmd reset

umount /dev/loop1

trace-cmd report -i file.dat
