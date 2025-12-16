#!/usr/bin/zsh -f

# Example:
# compile-test-patchset.sh reorder-commits compile-test ef3d8859 'make O=~/disk-imgs/junk/build/btrfs-next/ -j4 zImage' yes

branch_exists()
{
	git rev-parse --verify $1 > /dev/null 2>&1
}

create_dst_branch()
{
	dst_branch=$1
	head_commit=$2

	branch_exists $dst_branch
	if [[ $? == 0 ]]; then
		git branch -D $dst_branch || \
			{ print "Unable to delete $dst_branch\n"; return 1; }
	fi
	
	git checkout -b $dst_branch ${head_commit}^ || \
		{ print "Unable to checkout $dst_branch\n"; return 1; }

	return 0;
}

usage="Usage: $0 <src-branch> <dst-branch> <first commit> <build command> <break-on-build-failure>"

if [[ $ARGC != 5 ]]; then
	print $usage
	exit 1
fi

src_branch=$1
dst_branch=$2
first_commit=$3
build_command_line=$4
break_on_build_failure=$5

branch_exists $src_branch || \
	{ print "Branch $src_branch does not exist.\n"; exit 1; }

create_dst_branch $dst_branch $first_commit || exit 1

commit_list=$(git log --reverse $src_branch --pretty=format:"%h%n" $first_commit^..HEAD)

for commit in ${=commit_list}; do
	subject=$(git --no-pager log -n 1 --pretty=format:"%s%n" $commit)
	print "Applying commit \e[0;32m  $commit ... $subject  \e[0;m"
	git --no-pager cherry-pick --ff $commit || \
		{ print "Failed\n"; exit 1 }

        print "--------------------------------------------------------------------------------"
        git diff HEAD^..HEAD | /root/repos/linux/scripts/checkpatch.pl --emacs -
        print "--------------------------------------------------------------------------------"
	
	eval ${build_command_line} # > /dev/null 2>&1
	if [[ $? != 0 ]]; then
		print "Project build failed for commit $commit\n"
		[[ break_on_build_failure == "yes" ]] && exit 1
	fi
done
