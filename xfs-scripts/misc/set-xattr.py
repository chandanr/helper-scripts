#!/usr/bin/env python3

import os
import mmap
import sys
import time

def set_xattr(name_len, value_len, filename):
	name = 'a' * name_len
	value = 'b' * value_len

	# print(f"Name length = {name_len}; Value length = {value_len}")

	for i in range(1, 1000):
		tmp_name = 'trusted.' + str(i) + name
		# print(f"i = {i}")
		try:
			os.setxattr(filename, bytes(tmp_name, encoding='utf8'),
				    bytes(value, encoding='utf8'), os.XATTR_CREATE)
		except Exception as e:
			print(f"Failed to set xattr " + str(e))
			raise

	print("Successfully set xattr")

if len(sys.argv) != 4:
	print(f"Usage: {sys.argv[0]} <name length> <value length> <filename>")
	sys.exit(1)

name_len = int(sys.argv[1])
value_len = int(sys.argv[2])
filename = sys.argv[3]
	
set_xattr(name_len, value_len, filename)
