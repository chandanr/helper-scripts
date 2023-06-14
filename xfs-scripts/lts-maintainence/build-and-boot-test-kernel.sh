#!/bin/bash

datadir=/data/
kerneldir=${datadir}/linux-stable/
modulesdir=${datadir}/modules/
initramfs=${kerneldir}/initramfs.img
bzimage=${kerneldir}/arch/x86/boot/bzImage
git_test_branch=test-branch

if [[ $# != 1 ]]; then
	echo "Usage: $0 <commit id>"
	exit 1
fi
commit_id=$1

rm -rf $modulesdir
rm -rf $initramfs

mkdir $modulesdir
cd $kerneldir

echo "Performing an unshallow fetch"
git fetch --unshallow
if [[ $? != 0 ]]; then
	echo "Unable to execute git fetch"
fi

echo "Checking out commit: $commit_id"
git checkout -b $git_test_branch $commit_id
if [[ $? != 0 ]]; then
	echo "Git checkout failed"
fi

echo "Build kernel"
make -j4
if [[ $? != 0 ]]; then
	echo "Unable to build kernel"
	exit 1
fi

echo "Install modules"
make INSTALL_MOD_PATH=$modulesdir modules_install
if [[ $? != 0 ]]; then
	echo "Unable to install modules"
	exit 1
fi

echo "Build initramfs"
dracut -f --force-drivers "vfat ext4 xfs" \
       -k ${modulesdir}/lib/modules/"$(make kernelversion)"+/ \
       --kver="$(make kernelversion)"+ \
       $initramfs
if [[ $? != 0 ]]; then
	echo "Unable to initramfs image"
	exit 1
fi

kexec -l $bzimage --initrd $initramfs --reuse-cmdline
if [[ $? != 0 ]]; then
	echo "Kexec: Unable to load kernel image"
	exit 1
fi

systemctl kexec
