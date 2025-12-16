#!/usr/bin/zsh -f

groupadd fsgqa || { echo "Unable to add fsgqa group"; exit 1 }
useradd -g fsgqa -m fsgqa || { echo "Unable to add user fsgqa user"; exit 1 }

