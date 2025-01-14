#!/bin/bash

kill -SIGUSR2 $(pgrep pmlogger)
sleep 5s
pcp_archive=$(pcp | grep -i pmlogger | awk '{ print $4 }')
echo "PCP archive: ${pcp_archive}"

echo "log advisory on 5second {xfs.log}" | pmlc -P
echo "query xfs.log" | pmlc -P

./check xfs/538

kill -SIGUSR2 $(pgrep pmlogger)
