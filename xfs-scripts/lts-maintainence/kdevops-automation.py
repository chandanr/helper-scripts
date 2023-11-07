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
kernel_revspec = "xfs-6.7-mergeA"
kdevops_config_dir = "configs/kdevops-configs/"
kernel_config = "configs/kernel-configs/config-kdevops"

kdevops_remote_repo = "oracle-gitlab"
kdevops_fstests_script = "kdevops-fstests-iterate.sh"
kdevops_stop_iteration_file = "kdevops-stop-iteration"
fstests_baseline_cmd = "time " + kdevops_fstests_script + " {} 1 {} {} ./{}"

test_dirs = {
    "kdevops-all" : {
        'kdevops_branch' : "upstream-xfs-common-expunges",
        'expunges' : None,
        'nr_test_iters'  : 12,
    },

    "kdevops-externaldev" : {
        'kdevops_branch' : "upstream-xfs-externaldev-expunges",
        'expunges' : { 'all.txt' : ['xfs/538'] },
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
        'nr_test_iters'  : 2,
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

def print_repo_status():
    for td in test_dirs.keys():
        print(f"=> {td}")
        os.chdir(td)

        cmdstring = 'git --no-pager log -n 1 --pretty=format:"%H\t%ar%n"'
        cmd = shlex.split(cmdstring)
        commit = subprocess.check_output(cmd)
        commit = commit.decode()
        print(f"\t {commit}")

        os.chdir(top_dir)

def toggle_stop_iter_file():
    for td in test_dirs.keys():
        print(f"=> {td}")

        os.chdir(td)

        if os.path.exists(kdevops_stop_iteration_file):
            os.remove(kdevops_stop_iteration_file)
        else:
            with open(kdevops_stop_iteration_file, "w") as fp:
                pass

        os.chdir(top_dir)

def checkout_kdevops_git_branch():
    for td in test_dirs.keys():
        os.chdir(td)

        branch = test_dirs[td]['kdevops_branch']

        cmdstrings = [
            "git reset --hard HEAD",
            "git checkout " + branch,
            "git reset --hard " + kdevops_remote_repo + "/" + branch
        ]

        for cs in cmdstrings:
            cmd = shlex.split(cs)
            proc = subprocess.Popen(cmd)
            proc.wait()

            if proc.returncode < 0:
                print(f"\"{cmdstring}\" failed")
                sys.exit(1)

        os.chdir(top_dir)

def setup_expunges(kernel_version):
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

        dst = os.path.join(td, ".config")
        shutil.copy(src, dst)

def copy_kernel_build_config():
    for td in test_dirs.keys():
        shutil.copy(kernel_config,
                    td + "/playbooks/roles/bootlinux/templates/")

def set_quota_mount_options(quota_opts):
    for td in test_dirs.keys():
        config_path = td + "/.config"
        with open(config_path, "r") as f:
            content = f.read()

            if 'CONFIG_FSTESTS_XFS_QUOTA_ENABLED' in content:
                content = re.sub("^CONFIG_FSTESTS_XFS_QUOTA_ENABLED=.+$",
                                 "", content, flags = re.MULTILINE)
            if 'CONFIG_FSTESTS_XFS_MOUNT_QUOTA_OPTS' in content:
                content = re.sub("^CONFIG_FSTESTS_XFS_MOUNT_QUOTA_OPTS=.+$",
                                 "", content, flags = re.MULTILINE)

            if len(quota_opts) > 0:
                content = content + '\n' + 'CONFIG_FSTESTS_XFS_QUOTA_ENABLED=y\n'
                content = content + '\n' + \
                    'CONFIG_FSTESTS_XFS_MOUNT_QUOTA_OPTS=' + '"' + \
                    quota_opts + '"' + '\n'

        with open(config_path, "w") as f:
            f.write(content)


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

def get_kernel_version():
    kernel = ""

    for td in test_dirs.keys():
        os.chdir(td)

        cmdstring = ("ansible -i ./hosts --become-user root --become-method "
                     "sudo --become all -m command -a 'uname -r' ")

        print(f"{td}: Obtaining kernel version")
        cmd = shlex.split(cmdstring)
        vl = subprocess.check_output(cmd).decode()
        vl = vl.strip().split('\n')

        hosts = [ vl[i].split()[0] for i in range(len(vl)) if  i % 2 == 0 ]
        kvers = [ vl[i] for i in range(len(vl)) if i % 2 != 0 ]

        if kernel == "":
            kernel = kvers[0]

        for i in range(len(kvers)):
            if kvers[i] != kernel:
                print(f"Host: {hosts[i]} has booted into an invalid kernel "
                      "version: {kvers[i]}")
                sys.exit(1)

        os.chdir(top_dir)

    return kernel


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

def execute_fstests_baseline(kernel_version):
    for td in test_dirs.keys():
        print(f"=> {td}")
        os.chdir(td)

        nr_test_iters = test_dirs[td]['nr_test_iters']
        cmdstring = fstests_baseline_cmd.format(kernel_version, nr_test_iters,
                                                "./" + td + ".log",
                                                kdevops_stop_iteration_file)
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

def execute_tests():
    print("[automation] Checkout kdevops git branch")
    checkout_kdevops_git_branch()

    print("[automation] Copy kdevops config")
    copy_kdevops_config()

    print("[automation] Copy kernel build config")
    copy_kernel_build_config()

    print("[automation] Set up quota mount options")
    set_quota_mount_options(args.quota_opts)

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

    print("[automation] Obtain kernel version")
    kernel_version = get_kernel_version()

    print(f"[automation] Using kernel {kernel_version}")

    print("[automation] Create expunge list")
    setup_expunges(kernel_version)

    print("[automation] Build and install fstests")
    build_and_install_fstests()

    print("[automation] Execute fstests-baseline")
    execute_fstests_baseline(kernel_version)


parser = argparse.ArgumentParser(description="Automate kdevops usage")

group = parser.add_mutually_exclusive_group()
group.add_argument("-d", dest="destroy_resources", default=False,
                    action='store_true',
                    help="Destroy previously allocated resources",
                    required=False)
group.add_argument("-r", dest="print_repo_status", default=False,
                    action='store_true',
                    help="Print kdevops repository status",
                    required=False)
group.add_argument("-s", dest="toggle_stop_iter_file", default=False,
                   action='store_true',
                   help="Toggle stop iteration file",
                   required=False)
group.add_argument("-t", dest="execute_tests", default=False,
                   action='store_true',
                   help="Execute fstests",
                   required=False)

parser.add_argument("-q", dest="quota_opts", default="usrquota,grpquota,prjquota",
                    action='store',
                    help="Quota options to be passed during mount",
                    required=False)

args = parser.parse_args()

kdevops_dirs_exist()
kdevops_fstests_script_exists()

if args.destroy_resources:
    print("[automation] Destroying resources")
    destroy_resources()
elif args.print_repo_status:
    print("[automation] Print repository status")
    print_repo_status()
elif args.toggle_stop_iter_file:
    print("[automation] Toggle stop iteration file")
    toggle_stop_iter_file()
elif args.execute_tests:
    execute_tests()
else:
    print("[automation] Nothing to do")
