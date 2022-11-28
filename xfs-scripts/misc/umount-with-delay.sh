#!/usr/bin/zsh -f

# sleep 1s

umount $1

# if [[ $? != 0 ]]; then
# 	echo "Parent process hierarchy" > /tmp/chandan-pid.log
# 	ps -eax -o pid,ppid,command >> /tmp/chandan-pid.log
# fi
