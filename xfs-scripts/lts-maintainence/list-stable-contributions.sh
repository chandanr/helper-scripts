#!/bin/bash

usage="Usage: $0 <start-commit> <end-commit>"

if [[ $# != 2 ]]; then
	echo $usage
	exit 1
fi

start_commit=$1
end_commit=$2

git log --pretty=format:"%h" ${start_commit}^..${end_commit} -- fs/xfs | \
	while read -r commit; do
	signed_off_by=$(git --no-pager log -n 1 \
			    --pretty=format:"%(trailers:key=Signed-off-by)" \
			    $commit)

	echo $signed_off_by | grep -q -i 'chandan.babu@oracle.com'
	[[ $? != 0 ]] && continue

	echo $signed_off_by | grep -q -i 'gregkh@linuxfoundation.org'
	[[ $? != 0 ]] && continue

	acked_by=$(git --no-pager log -n 1 \
		       --pretty=format:"%(trailers:key=Acked-by)" \
		       $commit)
	echo $acked_by | grep -q -i 'djwong@kernel.org'
	[[ $? != 0 ]] && continue

	body=$(git --no-pager log -n 1 --pretty=format:"%b" $commit)
	echo $body | grep -q -E 'commit .+ upstream'
	[[ $? != 0 ]] && continue

	echo $commit
done
