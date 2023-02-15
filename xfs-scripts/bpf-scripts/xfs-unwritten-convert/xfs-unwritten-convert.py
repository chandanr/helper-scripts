#!/usr/bin/python

import argparse
import subprocess
import shlex
import time
import tabulate
from bcc import BPF

parser = argparse.ArgumentParser(description="Count unwritten to written converstion")
parser.add_argument("-c", dest="cmdline", help="Workload's command line",
                    required=True)
args = parser.parse_args()

# print(f"args.cmdline = {args.cmdline}")

b = BPF(src_file="xfs-unwritten-convert.c")
b.attach_tracepoint(tp="xfs:xfs_unwritten_convert", fn_name="trace_xfs_unwritten_convert")

cmdline = shlex.split(args.cmdline)
proc = subprocess.Popen(cmdline, stdout=subprocess.DEVNULL)
proc.wait()

nr_conversions = b["nr_conversions"][0].value

print(f"Nr unwritten conversions = {nr_conversions}")

