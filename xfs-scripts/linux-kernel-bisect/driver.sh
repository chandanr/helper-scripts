#!/bin/bash

logfile=/data/automate/bisect.log

/data/automate/eval-performance.sh >> $logfile 2>&1
if [[ $? != 0 ]]; then
    exit 1
fi

/data/automate/build-and-boot-kernel.sh >> $logfile 2>&1
