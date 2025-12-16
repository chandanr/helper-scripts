#!/bin/bash

dev=/dev/loop0
mntpnt=/mnt/
testfile_prefix=${mntpnt}/testfile

rm -rf ${testfile_prefix}*;

sync
