#!/usr/bin/bash

xfsprogs_dir=/root/repos/xfsprogs-for-next

cd $xfsprogs_dir

make clean && \
	OPTIMIZER="-g" BUILD_CFLAGS="-g" CFLAGS="-g" ./configure && \
	bear -- make -j10 # V=1

# make DIST_ROOT=/opt/xfsprogs-build/ install
