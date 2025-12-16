#!/bin/bash

fix_commits=()
candidate_commits=()

search_regex=(
	"assert"
	"bug"
	"corrupt"
	"fail"
	"fix"
	"leak"
	'rac.+'			# Variants of "race"
	"uaf"
	'use.*after.*free'
)

tag_exists()
{
	git rev-parse --verify $1 &>/dev/null
}

usage="Usage: $0 <start-tag> <end-tag>"

if [[ $# != 2 ]]; then
	echo $usage
	exit 1
fi


start_tag=$1
end_tag=$2

for tag in $start_tag $end_tag; do
	tag_exists $tag
	if [[ $? != 0 ]]; then
		echo "Invalid tag: $tag"
		exit 1
	fi
done

commit_list=$(git log --reverse --pretty=format:"%h%n" $start_tag..$end_tag \
		  fs/xfs)

for commit in $commit_list; do
	subject=$(git --no-pager log -n 1 --pretty=format:"%s%n" $commit)

	# Ignore merge commits
	echo $subject | grep -q -i '^merge'
	[[ $? == 0 ]] && continue

	fixes=$(git --no-pager log -n 1 \
		    --pretty=format:"%(trailers:key=Fixes,valueonly)" $commit)
	if [[ -n $fixes ]]; then
		fix_commits+=("$commit - $subject")
		continue
	fi

	# Filter out trailers
	nr_trailer_lines=$(git --no-pager log -n 1 \
			       --pretty=format:"%(trailers)" $commit | wc -l)
	body=$(git --no-pager log -n 1 --pretty=format:"%B" $commit | \
		       head -n -${nr_trailer_lines})
	
	for ((i = 0; i < ${#search_regex[@]}; i++)); do
		echo $body | grep -q -w -E -i "${search_regex[$i]}"
		if [[ $? == 0 ]]; then
			candidate_commits+=("$commit - $subject: ${search_regex[$i]}")
			break
		fi
	done
done

echo "--- Actual fixes ---"
for ((i = 1; i <= ${#fix_commits[@]}; i++)); do
	echo "$i: " "${fix_commits[((i - 1))]}"
done

echo -e "\n---- Possible fixes; Along with matching regex  ----"
for ((i = 1; i <= ${#candidate_commits[@]}; i++)); do
	echo "$i: " "${candidate_commits[((i - 1))]}"
done
