#!/bin/bash

usage="Usage: $0 <oldest-ancestor-commit> <latest-commit> <file-with-commit-id-list>"

if [[ $# != 3 ]]; then
	echo $usage
	exit 1
fi

# We search among the commits spanning the range: $start_commit..$end_commit
# For example: HEAD^^^^..HEAD
start_commit=$1
end_commit=$2
commit_list_file=$3

fixes=/tmp/fixes_list.log

git --no-pager log --pretty=format:"%H %(trailers:key=Fixes,valueonly)" \
    $start_commit..$end_commit -- fs/xfs | \
	awk '{
		if (length($2) != 0)
		   printf("%s %s\n", $1, $2);
	}' > $fixes

while read -r commit; do
	short_commit=$(git rev-parse --short $commit)

	cat $fixes | \
		awk -v commit=$short_commit '{
		        if (length($2) <= length(commit)) {
				needle = $2;
				haystack = commit;
			} else {
			        needle = commit;
				haystack = $2;
			}
			idx = index(haystack, needle);
			if (idx != 0)
			   printf("%s %s\n", $1, $2);
		}'
done < $commit_list_file
