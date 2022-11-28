#!/usr/bin/env python3

import os
import mmap
import sys

def do_dsync_direct_write(start, length, filename):
	buf = mmap.mmap(-1, length)

	print(f"File name is {filename}\n")
	fd = os.open(filename, os.O_DSYNC | os.O_RDWR | os.O_DIRECT | os.O_APPEND)
	os.pwrite(fd, buf, start)
	os.close(fd)


if len(sys.argv) != 4:
	print(f"Usage: {sys.argv[0]} <start offset> <length> <file name>")
	sys.exit(1)

start_offset = int(sys.argv[1])
length = int(sys.argv[2])
filename = sys.argv[3]

do_dsync_direct_write(start_offset, length, filename)
