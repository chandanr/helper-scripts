#!/bin/bash

datadir=/data/
kerneldir=${datadir}/linux-stable/
modulesdir=${datadir}/modules/
initramfs=${kerneldir}/initramfs.img
bzimage=${kerneldir}/arch/x86/boot/bzImage

if [[ $# < 1 ]]; then
	echo "Usage: ./$0 <fetch tag/commit>"
	exit 1
fi

rm -rf $modulesdir
rm -rf $initramfs

cd $kerneldir

git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git fetch --depth 1 origin $@

# git fetch --unshallow
# if [[ $? != 0 ]]; then
#	echo "Git fetch failed"
#	exit 1
# fi

git checkout -b linux-v6.5-rc5 v6.5-rc5
if [[ $? != 0 ]]; then
	echo "Git checkout failed"
	exit 1
fi

echo "Build kernel config"
yes "" | make oldconfig

echo "Build kernel"
make -j20
if [[ $? != 0 ]]; then
	echo "Unable to build kernel"
	exit 1
fi

echo "Install modules"
make INSTALL_MOD_PATH=${modulesdir} modules_install
if [[ $? != 0 ]]; then
	echo "Unable to install modules"
	exit 1
fi

kernelversion=$(ls ${modulesdir}/lib/modules/)

echo "Build initramfs" 
dracut -f --force-drivers "vfat ext4 loop" \
       -k ${modulesdir}/lib/modules/${kernelversion}/ \
       --kver="${kernelversion}" ${initramfs}
if [[ $? != 0 ]]; then
	echo "Unable to build initramfs"
	exit 1
fi

echo "Load kernel to kexec into"
kexec -l $bzimage --initrd  $initramfs --reuse-cmdline
if [[ $? != 0 ]]; then
	echo "Unable to load kernel using kexec"
	exit 1
fi

echo "Booting into new kernel"
systemctl kexec
