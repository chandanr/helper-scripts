#!/usr/bin/zsh -f

if [[ $ARGC != 1 ]]; then
	echo "Usage: $0 <commit subject>"
	exit 1
fi

commit=$(git --no-pager log --pretty=format:"%h - %s%n"  master | grep -i "$1")
commit=$(echo $commit | grep -v Merge)


commit=${commit%% *}

containing_tag=$(git describe --contains $commit)

echo "Commit id = $commit"
echo "Release = $containing_tag"
