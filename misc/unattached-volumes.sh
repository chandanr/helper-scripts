#!/bin/bash

set -euo pipefail

compartment_id=""
all_attachments=/home/chandan/junk/all-attachments.txt
our_volumes=/home/chandan/junk/our-volumes.txt

rm -f $all_attachments
oci compute volume-attachment list --compartment-id $compartment_id --all > \
    $all_attachments
if [[ $? != 0 ]]; then
	echo "oci compute volume-attachment list: failed"
	exit 1
fi

attached_ocids=$(cat $all_attachments | grep -i '\"id\":' | awk '{ print $2; }' | \
		    sed s/\"//g | sed s/,//g)
# echo "Attached ocids:"
# for ocid in $attached_ocids; do
# 	echo $ocid
# done

rm -f $our_volumes
for name in chanbabu-kdevops-data chanbabu-kdevops-sparse; do
	echo "Processing $name"
	oci bv volume list --compartment-id "$compartment_id" \
	    --display-name=${name} --lifecycle-state AVAILABLE >> $our_volumes
done

our_ocids=$(cat $our_volumes | grep -i '\"id\":' | awk '{ print $2; }' | \
		    sed s/\"//g | sed s/,//g)
echo "Unattached block volumes:"
for ocid in $our_ocids; do
	# echo $ocid
	grep -q $ocid $all_attachments
	if [[ $? == 0 ]]; then
		# echo "$ocid" >> /dev/stderr
		continue
	fi

	display_name=$(oci bv volume get --volume-id $ocid | \
			grep -i display-name | awk '{ print $2; }' \
			| sed s/\"//g | sed s/,//g)
	echo "$display_name: $ocid"
done
