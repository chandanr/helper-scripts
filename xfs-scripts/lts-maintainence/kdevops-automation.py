#!/usr/bin/env python

from junitparser import JUnitXml, Property, Properties, Failure, Error, Skipped
import subprocess
import argparse
import psutil
import shlex
import shutil
import glob
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
remote_kernel_dir="/data/xfs-linux"
kdevops_fstests_script = "kdevops-fstests-iterate.sh"
kdevops_stop_iteration_file = "kdevops-stop-iteration"
fstests_baseline_cmd = "time " + kdevops_fstests_script + " {} 1 {} {} ./{}"

test_dirs = {
    "kdevops-all" : {
        'kdevops_branch' : "upstream-xfs-common-expunges",
        'kdevops_results_archive_branch' : 'origin/main',
        'expunges' : None,
        'nr_test_iters'  : 12,
    },

    "kdevops-externaldev" : {
        'kdevops_branch' : "upstream-xfs-externaldev-expunges",
        'kdevops_results_archive_branch' : 'origin/main',
        'expunges' : { 'all.txt' : ['xfs/538'] },
        'nr_test_iters' : 12,
    },

    "kdevops-dangerous-fsstress-repair" : {
        'kdevops_branch' : "upstream-xfs-common-expunges",
        'kdevops_results_archive_branch' : 'origin/main',
        'expunges' : None,
        'nr_test_iters'  : 4,
    },

    "kdevops-dangerous-fsstress-scrub" : {
        'kdevops_branch' : "upstream-xfs-common-expunges",
        'kdevops_results_archive_branch' : 'origin/main',
        'expunges' : None,
        'nr_test_iters'  : 2,
    },

    "kdevops-recoveryloop" : {
        'kdevops_branch' : "upstream-xfs-common-expunges",
        'kdevops_results_archive_branch' : 'origin/main',
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
        td = os.path.join(td, "kdevops")
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

# Example invocation
# ./kdevops-automation.py -f "6.7.0-rc2+" | grep -o -E '(xfs|generic)\/[0-9]+' | sort | uniq | grep -v -f <(cat ~/junk/known-test-failures.txt | grep -o -E '(xfs|generic)\/[0-9]+' | sort | uniq)
def print_fail_tests_list(kernel_version):
    for td in test_dirs.keys():
        print(f"=> {td}")
        td = os.path.join(td, "kdevops")
        os.chdir(td)

        path = os.path.join("workflows/fstests/expunges/", kernel_version,
                            "xfs/unassigned")
        if not os.path.exists(path):
            print(f"{path} does not exist")
            sys.exit(1)

        for f in glob.glob(path + "/*.txt"):
            if os.stat(f).st_size == 0:
                continue
            print(f"-- {f}")
            with open(f, "r") as fp:
                for line in fp:
                    print(f"\t{line}", end="")

        os.chdir(top_dir)

# Find diff between two directories with the following command:
# diff -u --recursive --new-file <dir1> <dir2>
def print_skipped_tests_list(kernel_version, dest_dir):
    # pdb.set_trace()
    for td in test_dirs.keys():
        os.chdir(os.path.join(td, "kdevops"))

        kdevops_result_path = os.path.join(dest_dir, td)
        os.mkdir(kdevops_result_path)

        path = os.path.join("workflows/fstests/results/", kernel_version)
        for section in os.listdir(path):
            entry = os.path.join(path, section)
            if not os.path.isdir(entry):
                continue
            section_result_path = os.path.join(kdevops_result_path, section)

            with open(section_result_path, "w") as rfp:
                result_xml = os.path.join(entry, 'result.xml')
                if not os.path.isfile(result_xml):
                    continue

                junit_xml = JUnitXml.fromfile(result_xml)
                for tc in junit_xml:
                    for result in tc.result:
                        if not isinstance(result, Skipped):
                            continue

                        print(f"{tc.name}; {result.message}", file=rfp)

        os.chdir(top_dir)

def print_repo_status():
    for td in test_dirs.keys():
        print(f"=> {td}")
        td = os.path.join(td, "kdevops-results-archive")
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
        os.chdir(os.path.join(td, "kdevops"))

        branch = test_dirs[td]['kdevops_branch']

        cmdstrings = [
            "git reset --hard HEAD",
            "git checkout " + branch,
            "git fetch " + kdevops_remote_repo,
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

def checkout_kdevops_results_archive_git_branch():
    for td in test_dirs.keys():
        os.chdir(os.path.join(td, "kdevops-results-archive"))

        branch = test_dirs[td]['kdevops_results_archive_branch']

        cmdstrings = [
            "git reset --hard " + branch,
        ]

        for cs in cmdstrings:
            print(f"cs = {cs}")
            cmd = shlex.split(cs)
            proc = subprocess.Popen(cmd)
            proc.wait()

            if proc.returncode < 0:
                print(f"\"{cmdstring}\" failed")
                sys.exit(1)

        os.chdir(top_dir)

def enable_persistent_journal():
    for td in test_dirs.keys():
        td = os.path.join(td, "kdevops")
        os.chdir(td)

        cmdstring = ("ansible -i ./hosts --become-user root "
                     "--become-method sudo --become all "
                     "-m lineinfile -a  \"path=/etc/systemd/journald.conf "
                     "regexp='^#?Storage=.*$' line=Storage=persistent\"")

        cmd = shlex.split(cmdstring)
        proc = subprocess.Popen(cmd)
        proc.wait()

        os.chdir(top_dir)


def setup_expunges(kernel_version):
    commit_msg = 'chandan: Add expunge list'

    for td in test_dirs.keys():
        if test_dirs[td]['expunges'] == None:
            continue

        os.chdir(os.path.join(td, "kdevops"))

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
            spath = os.path.join(path, section)
            expunge_list = expunges[section]
            with open(spath, 'w') as f:
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
        src = os.path.join(kdevops_config_dir, td)

        if not os.path.exists(src):
            print(f'{src}: kdevops config file does not exist')
            exit(1)

        dst = os.path.join(td, "kdevops", ".config")
        shutil.copy(src, dst)

def copy_kernel_build_config():
    for td in test_dirs.keys():
        path = os.path.join(td, "kdevops",
                            "playbooks/roles/bootlinux/templates")
        shutil.copy(kernel_config, path)

def set_quota_mount_options(quota_opts):
    for td in test_dirs.keys():
        config_path = os.path.join(td, "kdevops", ".config")
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
        config_path = os.path.join(td, "kdevops", ".config")
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
        config_path = os.path.join(td, "kdevops", ".config")
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
        td = os.path.join(td, "kdevops")
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
        os.chdir(os.path.join(td, "kdevops"))

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


def disable_systemd_coredump():
    for td in test_dirs.keys():
        td = os.path.join(td, "kdevops")
        os.chdir(td)
        cmdstring = ('ansible -i ./hosts --become-user root'
                     ' --become-method sudo --become all -m sysctl -a'
                     ' "name=kernel.core_pattern value=/dev/null"')
        print(f"{td}: Disabling systemd coredump")
        cmd = shlex.split(cmdstring)
        proc = subprocess.Popen(cmd)
        proc.wait()
        os.chdir(top_dir)

def build_linux_kernel():
    for td in test_dirs.keys():
        os.chdir(os.path.join(td, "kdevops"))
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

def verify_kernel_head_commit():
    sha1 = ""
    subject = ""

    cmdstring = ("ansible -i ./hosts --become-user root --become-method "
                 "sudo --become all -m shell -a "
                 f"'cd {remote_kernel_dir}; "
                 "git --no-pager log -n 1 --pretty=format:\"%h %s%n\"'")

    for td in test_dirs.keys():
        td = os.path.join(td, "kdevops")
        os.chdir(td)

        print(f"{td}: Obtaining Linux HEAD commit")
        cmd = shlex.split(cmdstring)
        cl = subprocess.check_output(cmd).decode()
        cl = cl.strip().split('\n')

        hosts = [ cl[i].split()[0] for i in range(len(cl)) if  i % 2 == 0 ]
        commits = [ cl[i] for i in range(len(cl)) if i % 2 != 0 ]

        if sha1 == "" or subject == "":
            sha1 = commits[0].split(' ', 1)[0]
            subject = commits[0].split(' ', 1)[1]

        for i in range(len(commits)):
            csha1 = commits[i].split(' ', 1)[0]
            csubject = commits[i].split(' ', 1)[1]
            if csha1 != sha1 or csubject != subject:
                print(f"Host: {hosts[i]} has an invalid kernel head commit")
                print(f"\tExpected: SHA1 = {sha1}; SUBJECT = {subject}")
                print(f"\tGot: SHA1 = {csha1}; SUBJECT = {csubject}")
                sys.exit(1)

        os.chdir(top_dir)

    return (sha1, subject)

def get_kernel_version():
    kernel = ""

    for td in test_dirs.keys():
        td = os.path.join(td, "kdevops")
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
        td = os.path.join(td, "kdevops")
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
        os.chdir(os.path.join(td, "kdevops"))

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

def print_test_results():
    for td in test_dirs.keys():
        print(f"=> {td}")
        os.chdir(os.path.join(td, "kdevops"))

        print(f"{td}: Printing fstests progress")
        cmdstring = "ansible -i ./hosts --list-hosts all"
        cmd = shlex.split(cmdstring)
        hosts = subprocess.check_output(cmd)
        hosts = hosts.decode()
        hosts = hosts.strip().split('\n')[1:]
        for h in hosts:
            h = h.strip()
            print(f"\t host = {h}")
            cmdstring = f"ssh {h} -C 'journalctl -t fstests'"
            cmd = shlex.split(cmdstring)
            results = subprocess.check_output(cmd)
            results = results.decode()
            print(f"\t {results}")

        os.chdir(top_dir)


def execute_tests():
    print("[automation] Checkout kdevops git branch")
    checkout_kdevops_git_branch()

    print("[automation] Checkout kdevops results archive git branch")
    checkout_kdevops_results_archive_git_branch()

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

    print("[automation] Verify kernel HEAD commit")
    sha1, subject = verify_kernel_head_commit()
    print(f"Linux kernel HEAD commit: SHA1 = {sha1}; SUBJECT = {subject}")

    print("[automation] Obtain kernel version")
    kernel_version = get_kernel_version()

    print(f"[automation] Using kernel {kernel_version}")

    print("[automation] Enable persistent journal")
    enable_persistent_journal()

    print("[automation] Create expunge list")
    setup_expunges(kernel_version)

    print("[automation] Build and install fstests")
    build_and_install_fstests()

    print("[automation] Execute fstests-baseline")
    execute_fstests_baseline(kernel_version)


parser = argparse.ArgumentParser(description="Automate kdevops usage")

parser.add_argument("-D", dest="dest_dir", action='store', default=None,
                    help="Destination directory",
                    required=False)
group = parser.add_mutually_exclusive_group()
group.add_argument("-d", dest="destroy_resources", default=False,
                    action='store_true',
                    help="Destroy previously allocated resources",
                    required=False)
group.add_argument("-f", dest="fail_kernel_version", action='store', default=None,
                    help="Print a list of failed tests for a kernel",
                    required=False)
group.add_argument("-o", dest="skipped_kernel_version", action='store', default=None,
                    help="Print tests which were skipped",
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
group.add_argument("-T", dest="print_test_results", default=False,
                   action='store_true',
                   help="Print fstests test results",
                   required=False)
parser.add_argument("-q", dest="quota_opts", default="usrquota,grpquota,prjquota",
                    action='store',
                    help="Quota options to be passed during mount",
                    required=False)

args = parser.parse_args()

kdevops_dirs_exist()
kdevops_fstests_script_exists()

if args.dest_dir != None:
    if os.path.exists(args.dest_dir):
        print(f"{args.dest_dir} already exists; Please delete it")
        sys.exit(1)
    os.mkdir(args.dest_dir)

if args.destroy_resources:
    print("[automation] Destroying resources")
    destroy_resources()
elif args.fail_kernel_version != None:
    print(f"[automation] Print test fail list for {args.fail_kernel_version}")
    print_fail_tests_list(args.fail_kernel_version)
elif args.skipped_kernel_version != None:
    if args.dest_dir == None:
        print("Please specify '-D <destination directory' option",
              file=sys.stderr)
        sys.exit(1)
    print(f"[automation] Print skipped test list for {args.skipped_kernel_version}")
    print_skipped_tests_list(args.skipped_kernel_version, args.dest_dir)
elif args.print_repo_status:
    print("[automation] Print repository status")
    print_repo_status()
elif args.toggle_stop_iter_file:
    print("[automation] Toggle stop iteration file")
    toggle_stop_iter_file()
elif args.execute_tests:
    execute_tests()
elif args.print_test_results:
    print("[automation] Print test results")
    print_test_results()
else:
    print("[automation] Nothing to do")
