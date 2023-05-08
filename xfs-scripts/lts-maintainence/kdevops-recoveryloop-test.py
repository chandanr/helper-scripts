#!/usr/bin/python

import os
import sys
import shlex
import signal
import subprocess

prev_stats_file = ""
kvers = ""
start_iter = 0
end_iter = 0

results_dir = "./workflows/fstests/results/"
gen_results_summary = "./playbooks/python/workflows/fstests/gen_results_summary"
results_summary = "/tmp/results_summary.log"

snames = ["xfs_nocrc", "xfs_nocrc_512", "xfs_crc", "xfs_reflink",
          "xfs_reflink_1024", "xfs_reflink_normapbt", "xfs_logdev"]

tnames = ["generic/019", "generic/388", "generic/455", "generic/457",
          "generic/475", "generic/482", "generic/646", "generic/648",
          "xfs/057"]

sections = {}

def print_test_stats():
    global sections
    global snames
    global tnames

    print("Test statistics")
    print("---------------")

    for s in snames:
        print(f"Section: {s}")
        for t in tnames:
            print(f"\t{t}: {sections[s][t]}")

def read_prev_stats():
    global prev_stats_file
    section_found = 0
    sname = ""

    with open(prev_stats_file, "r") as f:
        for line in f:
            if section_found == 0:
                if not line.startswith("Section"):
                    print(f"{prev_stats_file}: Invalid format")
                    sys.exit(1)
                else:
                    section_found = 1
                    sname = line.split()[1]
                    continue

            if line.startswith("Section"):
                sname = line.split()[1]
                continue

            tname = line.split()[0]
            tcount = line.split()[1]

            sections[sname][tname] = sections[sname][tname] + tcount

    print_test_stats()
            
def init_sections():
    global prev_stats_file
    global sections

    for s in snames:
        sections[s] = {}
        for t in tnames:
            sections[s][t] = 0

    if prev_stats_file != "":
        read_prev_stats()

    print_test_stats()

def handle_sigint(signum, frame):
    print("Handle SIGINT")
    print_test_stats()
    sys.exit(1)

def handle_sigusr1(signum, frame):
    print("Handle SIGUSR1")
    print_test_stats()

def main():
    global kvers
    global start_iter
    global end_iter

    signal.signal(signal.SIGINT, handle_sigint)
    signal.signal(signal.SIGUSR1, handle_sigusr1)

    init_sections()

    cmdstring = "make fstests"
    print(f"Executing: {cmdstring}")
    cmd = shlex.split(cmdstring)
    proc = subprocess.Popen(cmd)
    proc.wait()

    if proc.returncode < 0:
        print(f"\"{cmdstring}\" failed")
        sys.exit(1)

    for i in range(start_iter, end_iter + 1):
        print(f"---- Iteration: {i} ----")

        cmdstring = "make fstests-baseline"
        print(f"Executing: {cmdstring}")
        cmd = shlex.split(cmdstring)
        proc = subprocess.Popen(cmd)
        proc.wait()

        if proc.returncode < 0:
            print(f"\"{cmdstring}\" failed")
            sys.exit(1)

        for s in snames:
            sresults = results_dir + kvers + '/' + s + '/'

            cmdstring = gen_results_summary + \
                " --results_file result.xml" + " --print_section " \
                + sresults + " --verbose"
            # print(f"{s}: Computing test summary stats")
            # print(f"Executing {cmdstring}")
            cmd = shlex.split(cmdstring)

            os.unlink(results_summary)

            with open(results_summary, "wt") as rs:
                proc = subprocess.Popen(cmd, stdout=rs)
                proc.wait()

                if proc.returncode < 0:
                    print(f"\"{cmdstring}\" failed")
                    sys.exit(1)

            with open(results_summary, "rt") as rs:
                for line in rs:
                    line = line.strip()
                    if len(line) == 0:
                        continue

                    if not line.startswith("generic/") and \
                       not line.startswith("xfs/"):
                        continue

                    tname = line.split()[0]
                    tstatus = line.split()[1]
                    if tstatus == "Fail":
                            sections[s][tname] = sections[s][tname] + 1

            if i % 10 == 0:
                print_test_stats()

    print_test_stats()

    return None

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <kernel version> <start iteration> "\
              "<end iteration count> <previous stats>")
        sys.exit(1)

    kvers = sys.argv[1]
    start_iter = int(sys.argv[2])
    end_iter = int(sys.argv[3])

    if len(sys.argv) == 3:
        prev_stats_file = sys.argv[4]

    main()
