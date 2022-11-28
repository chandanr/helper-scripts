#!/usr/bin/env python3

import os
import mmap
import sys
import time

def do_buffered_write(start, length, filename):
	buf = mmap.mmap(-1, length)

	print(f"File name is {filename}\n")
	fd = os.open(filename, os.O_CREAT | os.O_SYNC | os.O_WRONLY)
	os.pwrite(fd, buf, start)
	# Sleep time has to be larger than
	# /proc/sys/fs/xfs/speculative_prealloc_lifetime seconds
	time.sleep(10)
	os.close(fd)


if len(sys.argv) != 4:
	print(f"Usage: {sys.argv[0]} <start offset> <length> <file name>")
	sys.exit(1)

start_offset = int(sys.argv[1])
length = int(sys.argv[2])
filename = sys.argv[3]

do_buffered_write(start_offset, length, filename)
