#!/bin/bash

if [[ $# != 2 ]]; then
    echo "Usage: $0 <log directory> <graphs directory>"
    exit 1
fi

log_files_dir=$1
graphs_dir=$2

rm -rf ${graphs_dir}
mkdir ${graphs_dir}

for f in $(ls -1 ${log_files_dir}/inode-*); do
    filename=$(basename $f)
    ino=$(echo $filename | awk -F'[-.]' '{print($2)}')
    gnuplot <<EOF
    set terminal pngcairo enhanced size 1916,1012
    set output "${graphs_dir}/inode-${ino}.png"

    set xlabel "Time"
    set ylabel "Dio list length"

    set yrange [*<0:]
    set xtic 250000000
    set ytic auto

    set title "Dio list length"
    plot "$f" with impulses
EOF
done
