#!/bin/bash

source local.config

modulesdir=${datadir}/modules/
initramfs=${kerneldir}/initramfs.img
bzimage=${kerneldir}/arch/x86/boot/bzImage

if [[ -d ${modulesdir}/lib/modules/ ]]; then
    kernelversion=$(ls ${modulesdir}/lib/modules/)
    symlink="/lib/modules/${kernelversion}"
    if [[ -h $symlink ]]; then
	echo "Removing symbolic link $symlink"
	rm -rf $symlink
	[[ -h $symlink ]] && echo "Warning: symlink still exists"
    fi
fi

rm -rf $modulesdir
rm -rf $initramfs

cd $kerneldir

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
symlink="/lib/modules/${kernelversion}"

if [[ -h $symlink ]]; then
    echo "Removing symbolic link $symlink"
    rm -rf $symlink
    [[ -h $symlink ]] && echo "Warning: symlink still exists"
fi

ln -s ${modulesdir}/lib/modules/${kernelversion} /lib/modules/${kernelversion}

echo "Contents of /lib/modules/${kernelversion}"
ls -lh /lib/modules/${kernelversion}

echo "Build initramfs" 
dracut -f --force-drivers "vfat ext4 loop dm_flakey" \
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
