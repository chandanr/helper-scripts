#!/usr/bin/python

# 2 minutes execution
#   List size    Nr samples    Percent
# -----------  ------------  ---------
#           1       4260272      48.07
#           2       1777548      20.05
#           3        894770      10.09
#           4        513825       5.8
#           5        324731       3.66
#           6        222733       2.51
#           7        162362       1.83
#           8        134549       1.52
#           9         94686       1.07
#          10         76132       0.86
#          11         63614       0.72
#          12         58107       0.66
#          13         68058       0.77
#          14        119444       1.35
#          15         68439       0.77
#          16         24284       0.27

import argparse
import subprocess
import shlex
import time
import tabulate
from bcc import BPF

parser = argparse.ArgumentParser(description="Compute dio list's length")
parser.add_argument("-c", dest="cmdline", help="Workload's command line",
                    required=True)
args = parser.parse_args()

# print(f"args.cmdline = {args.cmdline}")

b = BPF(src_file="dio-list-len.c")
b.attach_kprobe(event="xfs_end_dio+303", fn_name="trace_xfs_end_dio")

cmdline = shlex.split(args.cmdline)
proc = subprocess.Popen(cmdline, stdout=subprocess.DEVNULL)
proc.wait()

sum = 0
for i in range(0, 16):
    nr_samples = b["dio_list_len"][i].value
    sum = sum + nr_samples

table = [["List size", "Nr samples", "Percent"]]
for i in range(0, 16):
    element = b["dio_list_len"][i]
    nr_samples = element.value
    percent = (nr_samples * 100) / sum
    percent = round(percent, 2)
    table.append([i+1, nr_samples, percent])

print(tabulate.tabulate(table, headers='firstrow'))

