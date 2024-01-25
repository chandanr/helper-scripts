#!/bin/bash

session="kdevops"

kdevops_dir="/root/repos/kdevops"
kdevops_test_configs=(
	"kdevops-all"
	"kdevops-externaldev"
	"kdevops-dangerous-fsstress-repair"
	"kdevops-dangerous-fsstress-scrub"
	"kdevops-recoveryloop"
)

cd $kdevops_dir

tmux new-session -d -s $session

window=0
tmux rename-window -t $session:$window "kdevops-control"
tmux send-keys -t $session:$window "emacs" C-m

for ktc in ${kdevops_test_configs[@]}; do
	((window = window + 1))
	tmux new-window -t $session:$window -n $ktc
	tmux send-keys -t $session:$window "cd $ktc" C-m
	tmux send-keys -t $session:$window "emacs" C-m
done

tmux attach-session -t $session

