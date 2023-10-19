#!/usr/bin/env python

import subprocess
import argparse
import psutil
import shlex
import shutil
import stat
import time
import pdb
import sys
import os
import re

top_dir = os.getcwd()
kernel_revspec = "linux-v6.6-rc6"
kernel_version = "6.6.0-rc6+"
kdevops_config_dir = "configs/kdevops-configs/"
kernel_config = "configs/kernel-configs/config-kdevops"

kdevops_remote_repo = "oracle-gitlab"
kdevops_fstests_script = "kdevops-fstests-iterate.sh"
fstests_baseline_cmd = "time " + kdevops_fstests_script + " {} 1 {} {} ./kdevops-stop-iteration"

test_dirs = {
    "kdevops-all" : {
        'kdevops_branch' : "upstream-xfs-common-expunges",
        'expunges' : None,
        'nr_test_iters'  : 12,
    },

    "kdevops-externaldev" : {
        'kdevops_branch' : "upstream-xfs-externaldev-expunges",
        'expunges' : { 'all.txt' : ['xfs/438', 'xfs/538'] },
        'nr_test_iters' : 12,
    },

    "kdevops-dangerous-fsstress-repair" : {
        'kdevops_branch' : "upstream-xfs-common-expunges",
        'expunges' : None,
        'nr_test_iters'  : 4,
    },

    "kdevops-dangerous-fsstress-scrub" : {
        'kdevops_branch' : "upstream-xfs-common-expunges",
        'expunges' : None,
        'nr_test_iters'  : 1,
    },

    "kdevops-recoveryloop" : {
        'kdevops_branch' : "upstream-xfs-common-expunges",
        'expunges' : None,
        'nr_test_iters'  : 15,
    },
}

def kdevops_dirs_exist():
    for td in test_dirs.keys():
        statinfo = os.stat(td)
        if not stat.S_ISDIR(statinfo.st_mode):
            raise Exception(f"{td} is not a directory")

def kdevops_fstests_script_exists():
    if shutil.which(kdevops_fstests_script) == None:
        raise Exception(f"{kdevops_fstests_script} does not exist in $PATH")

def destroy_resources():
    print("[automation] Destroying resources")
    for td in test_dirs.keys():
        print(f"=> {td}")
        os.chdir(td)

        cmdstring = "make destroy"

        print(f"{td}: Destroying resources")
        cmd = shlex.split(cmdstring)
        proc = subprocess.Popen(cmd)
        proc.wait()

        if proc.returncode < 0:
            print(f"\"{cmdstring}\" failed")
            sys.exit(1)

        os.chdir(top_dir)

def checkout_kdevops_git_branch():
    for td in test_dirs.keys():
        os.chdir(td)

        branch = test_dirs[td]['kdevops_branch']

        cmdstrings = [
            "git reset --hard HEAD",
            "git checkout " + branch,
            "git reset --hard HEAD"
        ]

        for cs in cmdstrings:
            cmd = shlex.split(cs)
            proc = subprocess.Popen(cmd)
            proc.wait()

            if proc.returncode < 0:
                print(f"\"{cmdstring}\" failed")
                sys.exit(1)

        os.chdir(top_dir)

def setup_expunges():
    commit_msg = 'chandan: Add expunge list'

    for td in test_dirs.keys():
        if test_dirs[td]['expunges'] == None:
            continue

        os.chdir(td)

        cmdstring = "git log -n 1 --pretty=format:'%s'"
        cmd = shlex.split(cmdstring)
        subject = subprocess.check_output(cmd)
        subject = subject.decode()
        if subject == commit_msg:
            cmdstring = "git reset --hard HEAD^"
            cmd = shlex.split(cmdstring)
            proc = subprocess.Popen(cmd)
            proc.wait()

            if proc.returncode < 0:
                print(f"\"{cmdstring}\" failed")
                sys.exit(1)

        path = os.path.join("workflows/fstests/expunges/", kernel_version,
                            'xfs/unassigned')
        os.makedirs(path, exist_ok=True)

        expunges = test_dirs[td]['expunges']
        for section in expunges.keys():
            path = os.path.join(path, section)
            expunge_list = expunges[section]
            with open(path, 'w') as f:
                for test in expunge_list:
                    f.write(test + '\n')

        cmdstrings = [
            "git add " + path,
            "git commit -m '" + commit_msg + "'",
            "git push " + kdevops_remote_repo + " +HEAD",
        ]

        for cs in cmdstrings:
            cmd = shlex.split(cs)
            proc = subprocess.Popen(cmd)
            proc.wait()

            if proc.returncode < 0:
                print(f"\"{cmdstring}\" failed")
                sys.exit(1)

        os.chdir(top_dir)

def copy_kdevops_config():
    for td in test_dirs.keys():
        src = kdevops_config_dir + "/" + td

        if not os.path.exists(src):
            print(f'{src}: kdevops config file does not exist')
            exit(1)

        shutil.copy(src, td + ".config")

def copy_kernel_build_config():
    for td in test_dirs.keys():
        shutil.copy(kernel_config,
                    td + "/playbooks/roles/bootlinux/templates/")

def set_kernel_git_tree_revspec():
    for td in test_dirs.keys():
        config_path = td + "/.config"
        with open(config_path, "r") as f:
            content = f.read()
            # TODO: Why is kernel_revspec mentioned twice in the .config
            content = re.sub("^CONFIG_BOOTLINUX_CUSTOM_TAG=.+$",
                             "CONFIG_BOOTLINUX_CUSTOM_TAG=" + kernel_revspec,
                             content, flags = re.MULTILINE)
            content = re.sub("^CONFIG_BOOTLINUX_TREE_TAG=.+$",
                             "CONFIG_BOOTLINUX_TREE_TAG=" + kernel_revspec,
                             content, flags = re.MULTILINE)

        with open(config_path, "w") as f:
            f.write(content)

def set_kdevops_git_tree_custom_tag():
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

def build_kdevops():
    for td in test_dirs.keys():
        print(f"=> {td}")
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

def bringup_cloud_instances():
    for td in test_dirs.keys():
        os.chdir(td)

        cmdstring = "make bringup"
        print(f"{td}: Bringing up instance")
        cmd = shlex.split(cmdstring)
        proc = subprocess.Popen(cmd)
        test_dirs[td]['popen'] = proc

        # Wait until terrform starts
        terraform_running = False
        while not terraform_running:
            for p in psutil.process_iter():
                pname = psutil.Process(p.pid).name()
                if re.match('terraform.*', pname):
                    terraform_running = True
                    break
            time.sleep(1)

        print(f"{td} terraform process started")

        # Wait until .ssh/config entries are added
        while True:
            terraform_running = False

            for p in psutil.process_iter():
                pname = psutil.Process(p.pid).name()
                if re.match('terraform.*', pname):
                    print(f"{td} Waiting for terraform process {p.pid} to complete")
                    terraform_running = True
                    time.sleep(1)
                    break

            if not terraform_running:
                print(f"{td} terraform process completed")
                break

        os.chdir(top_dir)

    for td in test_dirs.keys():
        proc = test_dirs[td]['popen']
        test_dirs[td]['popen'] = None
        proc.wait()

        if proc.returncode < 0:
            print(f"{td}: Bringup failed")
            sys.exit(1)


def build_linux_kernel():
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
        test_dirs[td]['popen'] = None
        proc.wait()

        if proc.returncode < 0:
            print(f"{td}: Building Linux kernel failed")
            sys.exit(1)

def build_and_install_fstests():
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

def execute_fstests_baseline():
    for td in test_dirs.keys():
        print(f"=> {td}")
        os.chdir(td)

        nr_test_iters = test_dirs[td]['nr_test_iters']
        cmdstring = fstests_baseline_cmd.format(kernel_version, nr_test_iters,
                                                "./" + td + ".log")
        print(f"{td}: Started fstests-baseline loop")
        print(f"cmdstring = {cmdstring}")
        cmd = shlex.split(cmdstring)
        proc = subprocess.Popen(cmd)
        test_dirs[td]['popen'] = proc

        os.chdir(top_dir)

    for td in test_dirs.keys():
        proc = test_dirs[td]['popen']
        test_dirs[td]['popen'] = None
        proc.wait()

        if proc.returncode < 0:
            print(f"{td}: fstests-baseline loop failed")
            sys.exit(1)

parser = argparse.ArgumentParser(description="Automate kdevops usage")
parser.add_argument("-d", dest="destroy_resources", default=False,
                    action='store_true',
                    help="Destroy previously allocated resources",
                    required=False)
args = parser.parse_args()

kdevops_dirs_exist()
kdevops_fstests_script_exists()

if args.destroy_resources:
    destroy_resources()
    sys.exit(0)

print("[automation] Checkout kdevops git branch")
checkout_kdevops_git_branch()

print("[automation] Create expunge list")
setup_expunges()

print("[automation] Copy kdevops config")
copy_kdevops_config()

print("[automation] Copy kernel build config")
copy_kernel_build_config()

print("[automation] Set kernel git tree revspec")
set_kernel_git_tree_revspec()

print("[automation] Set kdevops git tree custom tag")
set_kdevops_git_tree_custom_tag()

print("[automation] Build kdevops")
build_kdevops()

print("[automation] Bring up cloud instances")
bringup_cloud_instances()

print("[automation] Build Linux kernel")
build_linux_kernel()

print("[automation] Build and install fstests")
build_and_install_fstests()

print("[automation] Execute fstests-baseline")
execute_fstests_baseline()
