#!/usr/bin/bash

xfsprogs_dir=/root/repos/xfsprogs-dev

cd $xfsprogs_dir

make clean && \
	OPTIMIZER="-g" BUILD_CFLAGS="-g" CFLAGS="-g" ./configure && \
	make -j10

# make DIST_ROOT=/opt/xfsprogs-build/ install
	
