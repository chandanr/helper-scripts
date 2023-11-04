#!/bin/bash

source local.config

cd $kerneldir

commit=$(git --no-pager log -1 --oneline | awk '{print($1);}')
echo "------- commit: $commit ------"

cd -

result=good

# Execute test
${test_script}

[[ $? != 0 ]] && result=bad

echo "Test result = $result"

cd $kerneldir

# TODO: Detect end of bisect and stop further processing

git bisect $result
if [[ $? != 0 ]]; then
    echo "Git bisect failed"
    systemctl stop bisect.service
    systemctl disable bisect.service
    exit 1
fi

cat $logfile | grep -q -i "is the first bad commit"
if [[ $? == 0 ]]; then
    echo "First bad commit found"
    systemctl stop bisect.service
    systemctl disable bisect.service
    exit 1
fi

exit 0
