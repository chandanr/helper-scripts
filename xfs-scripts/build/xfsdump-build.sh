#!/usr/bin/bash

xfsdump_dir=/root/repos/xfsdump-dev/

cd $xfsdump_dir

make clean && \
	OPTIMIZER="-g" BUILD_CFLAGS="-g" CFLAGS="-g" ./configure && \
	make -j10
