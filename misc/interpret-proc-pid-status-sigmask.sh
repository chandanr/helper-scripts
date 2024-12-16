#!/usr/bin/bash

# Obtained from somewhere on the internet.

if [[ $# != 2 ]]; then
	echo "Usage: $0 <pid> <field name>"
	exit 1
fi

pid=$1
field=$2

mask=$(cat /proc/${pid}/status | grep -i $field | awk '{ print $2; }')

bin=$(echo "ibase=16; obase=2; ${mask^^*}" | bc)
echo "Field: $field Mask: $mask"

i=1
while [[ $bin -ne 0 ]]; do
	if [[ ${bin:(-1)} -eq 1 ]]; then
		kill -l $i | tr '\n' ' '
	fi

	bin=${bin::-1}
	set $((i++))
done

echo
