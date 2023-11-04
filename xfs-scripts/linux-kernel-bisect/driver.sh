#!/bin/bash

source local.config

${scripts_dir}/eval-performance.sh >> $logfile 2>&1
if [[ $? != 0 ]]; then
    exit 1
fi

${scripts_dir}/build-and-boot-kernel.sh >> $logfile 2>&1
