#!/usr/bin/python

import argparse
import subprocess
import shlex
import time
import sys
import tabulate
from bcc import BPF

ts = {}
def print_event(cpu, data, size):
    global ts
    event = b["events"].event(data)
    if not event.ino in ts:
        ts[event.ino] = event.ts
        
    print(f"orig_ts = {event.ts}; ts = {event.ts - ts[event.ino]}; inode = {event.ino}; dio_list_len = {event.dio_list_len}")

parser = argparse.ArgumentParser(description="Retrieve inode's dio list's length")
parser.add_argument("-c", dest="cmdline", help="Workload's command line",
                    required=True)
args = parser.parse_args()

# print(f"args.cmdline = {args.cmdline}")

b = BPF(src_file="dio-list-len-across-time.c")
b.attach_kprobe(event="xfs_end_dio+303", fn_name="trace_xfs_end_dio")

b["events"].open_ring_buffer(print_event)

print("Starting workload ...", file=sys.stderr)
cmdline = shlex.split(args.cmdline)
proc = subprocess.Popen(cmdline, stdout=subprocess.DEVNULL)

while proc.poll() is None:
    try:
        b.ring_buffer_poll(30)
    except KeyboardInterrupt:
        exit()

print("... Completed executing the workload", file=sys.stderr)
