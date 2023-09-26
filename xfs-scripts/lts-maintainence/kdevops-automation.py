#!/usr/bin/env python

import subprocess
import shlex
import shutil
import sys
import os
import re

# TODOs
# 1. Copy kdevops config from config/ directory.

top_dir = os.getcwd()
kernel_config = "config/config-kdevops"
kernel_branch = "xfs-6.6-fixesB"

test_dirs = {
    # external-dev
    "kdevops-expr1" : {
        'kdevops_branch' : "upstream-xfs-externaldev-expunges",
    },
    # reflink-nrext64
    "kdevops-expr2" : {
        'kdevops_branch' : "upstream-xfs-common-expunges",
    },
}

# Copy kernel build config
for td in test_dirs.keys():
    shutil.copy(kernel_config,
                td + "/playbooks/roles/bootlinux/templates/")

# Set kernel git tree custom tag
for td in test_dirs.keys():
    config_path = td + "/.config"
    with open(config_path, "r") as f:
        content = f.read()
        content = re.sub("^CONFIG_BOOTLINUX_CUSTOM_TAG=.+$",
                         "CONFIG_BOOTLINUX_CUSTOM_TAG=" + kernel_branch,
                         content, flags = re.MULTILINE)
        content = re.sub("^CONFIG_BOOTLINUX_TREE_TAG=.+$",
                         "CONFIG_BOOTLINUX_TREE_TAG=" + kernel_branch,
                         content, flags = re.MULTILINE)
        
    with open(config_path, "w") as f:
        f.write(content)

# Set kdevops git tree custom tag
for td in test_dirs.keys():
    config_path = td + "/.config"
    kdevops_branch = test_dirs[td]['kdevops_branch']

    with open(config_path, "r") as f:
        content = f.read()
        content = re.sub("^CONFIG_WORKFLOW_KDEVOPS_GIT_VERSION=.+$",
                         "CONFIG_WORKFLOW_KDEVOPS_GIT_VERSION=" + kdevops_branch,
                         content, flags = re.MULTILINE)
        
    with open(config_path, "w") as f:
        f.write(content)

# Execute make
for td in test_dirs.keys():
    os.chdir(td)
    cmdstring = "make"
    print(f"{td}: Executing make")
    cmd = shlex.split(cmdstring)
    proc = subprocess.Popen(cmd)
    proc.wait()

    if proc.returncode < 0:
        print(f"\"{cmdstring}\" failed")
        sys.exit(1)

    os.chdir(top_dir)


# Bring up cloud instances
for td in test_dirs.keys():
    os.chdir(td)
    cmdstring = "make bringup"
    print(f"{td}: Bringing up instance")
    cmd = shlex.split(cmdstring)
    proc = subprocess.Popen(cmd)
    proc.wait()

    if proc.returncode < 0:
        print(f"\"{cmdstring}\" failed")
        sys.exit(1)

    os.chdir(top_dir)

# Build Linux kernel
for td in test_dirs.keys():
    os.chdir(td)
    cmdstring = "make linux"
    print(f"{td}: Started linux kernel build")
    cmd = shlex.split(cmdstring)
    proc = subprocess.Popen(cmd)
    test_dirs[td]['popen'] = proc
    os.chdir(top_dir)

for td in test_dirs.keys():
    proc = test_dirs[td]['popen']
    proc.wait()

    if proc.returncode < 0:
        print(f"{td}: Building Linux kernel failed")
        sys.exit(1)

# Build and install fstests
for td in test_dirs.keys():
    os.chdir(td)
    cmdstring = "make fstests"
    print(f"{td}: Building and installing fstests")
    cmd = shlex.split(cmdstring)
    proc = subprocess.Popen(cmd)
    proc.wait()

    if proc.returncode < 0:
        print(f"\"{cmdstring}\" failed")
        sys.exit(1)

    os.chdir(top_dir)

