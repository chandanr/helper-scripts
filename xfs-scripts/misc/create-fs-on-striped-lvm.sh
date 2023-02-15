#!/bin/bash

devices=(/dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1 /dev/nvme4n1)
vgname=perf-test-vg
lvname=perf-test-lv
mountpoint=/test

umount $mountpoint > /dev/null 2>&1

lvdisplay ${vgname}/${lvname} > /dev/null 2>&1
if [[ $? == 0 ]]; then
    echo "Deleting LV $lvname"
    lvremove -f -y ${vgname}/${lvname}
    if [[ $? != 0 ]]; then
	echo "Unable to remove LV"
	exit 1
    fi
fi

vgdisplay $vgname > /dev/null 2>&1
if [[ $? == 0 ]]; then
    echo "Deleting VG $vgname"
    vgremove -f $vgname
    if [[ $? != 0 ]]; then
	echo "Unable to remove VG"
	exit 1
    fi
fi

echo "Create PVs"
for d in $devices; do
    pvcreate -ff $d
    if [[ $? != 0 ]]; then
	echo "Unable to create PV on $d"
	exit 1
    fi
done

echo "---- PVs ----"
pvs

echo "Create VG"
vgcreate -f $vgname ${devices[@]}
if [[ $? != 0 ]]; then
    echo "Unable to create VG"
    exit 1
fi

echo "---- VG info ---"
vgdisplay $vgname

echo "Create LV"
lvcreate -y -n $lvname -l 100%FREE -i 4  $vgname
if [[ $? != 0 ]]; then
    echo "Unable to create LV"
    exit 1
fi

echo "---- LV info ----"
lvs

echo "Create FS"
mkfs.xfs -f /dev/${vgname}/${lvname}
if [[ $? != 0 ]]; then
    echo "Unable to create fs"
    exit 1
fi


echo "Mounting FS"
mount /dev/${vgname}/${lvname} $mountpoint
if [[ $? != 0 ]]; then
    echo "Unable to mount fs"
    exit 1
fi
