#!/bin/bash

datadir=/data/
kerneldir=${datadir}/linux-v5.19/
modulesdir=${datadir}/modules/
initramfs=${kerneldir}/initramfs.img
bzimage=${kerneldir}/arch/x86/boot/bzImage
patches_dir=/data/automate/patches/
patched_kernel=0

rm -rf $modulesdir
rm -rf $initramfs

cd $kerneldir

echo "Build kernel config"
yes "" | make oldconfig

echo "Build kernel"
make -j20
if [[ $? != 0 ]]; then
    echo "Try to build kernel after applying patch"
    for p in $(ls -1 $patches_dir); do
	patch -p1 < ${patches_dir}/${p}
	if [[ $? != 0 ]]; then
	    echo "Unable to patch kernel"
	    exit 1
	fi
    done

    patched_kernel=1
    make -j20
    if [[ $? != 0 ]]; then
	echo "Unable to build patched kernel"
	exit 1
    fi
fi

echo "Install modules"
make INSTALL_MOD_PATH=${modulesdir} modules_install
if [[ $? != 0 ]]; then
    echo "Unable to install modules"
    exit 1
fi

kernelversion=$(ls ${modulesdir}/lib/modules/)

echo "Build initramfs" 
dracut -f --force-drivers "vfat ext4" \
       -k ${modulesdir}/lib/modules/${kernelversion}/ \
       --kver="${kernelversion}" ${initramfs}
if [[ $? != 0 ]]; then
    echo "Unable to build initramfs"
    exit 1
fi

if [[ $patched_kernel == 1 ]]; then
    echo "Reseting patched kernel sources"
    cd $kerneldir
    git reset --hard HEAD
fi

echo "Load kernel to kexec into"
kexec -l $bzimage --initrd  $initramfs --reuse-cmdline
if [[ $? != 0 ]]; then
    echo "Unable to load kernel using kexec"
    exit 1
fi

echo "Booting into new kernel"
systemctl kexec
