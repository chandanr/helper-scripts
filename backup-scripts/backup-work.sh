#!/bin/bash

# A script to perform incremental backups using rsync
# Copied from:
# https://linuxconfig.org/how-to-create-incremental-backups-using-rsync-on-linux

set -o errexit
set -o nounset
set -o pipefail

log_file=~/junk/backup.log

readonly dotfiles=(
	"/home/chandan/.imapfilter"
	"/home/chandan/.mutt"
	"/home/chandan/.newsboat"
	"/home/chandan/.bashrc"
	"/home/chandan/.gitconfig"
	"/home/chandan/.mbsyncrc"
	"/home/chandan/.msmtprc"
)

dotfiles_dir="/home/chandan/junk/dotfiles"
rm -rf $dotfiles_dir
mkdir $dotfiles_dir
for f in ${dotfiles[@]}; do
	cp -r $f $dotfiles_dir
done

declare -A SOURCE_DIRS=(
	"mail-kerneldotorg" "/home/chandan/mail/kerneldotorg"
	"work-inbox" "/home/chandan/mail/work/INBOX"
	"work-linux-brownbags-group" "/home/chandan/mail/work/linux-brownbags-group"
	"work-misc" "/home/chandan/mail/work/misc"
	"dotfiles" "$dotfiles_dir"
	"work-ssh-keys" "/shared-documents/Oracle Content/configurations/ssh-keys"
)

remote_backup_dir="/home/chandan/junk/backups"
datetime="$(date '+%Y-%m-%d_%H:%M:%S')"

# rm -rf $remote_backup_dir
# mkdir -p "${remote_backup_dir}"

for d in ${!SOURCE_DIRS[@]}; do
	src_dir=${SOURCE_DIRS[${d}]}
	echo "rsync: $src_dir"

	backup_path="${remote_backup_dir}/${d}/${datetime}"
	latest_link="${remote_backup_dir}/${d}/latest"

	rsync --mkpath -s -av --delete "${src_dir}/" --link-dest "${latest_link}" \
	      --exclude=".cache" "${backup_path}"

	rm -rf "${latest_link}"
	ln -s "${backup_path}" "${latest_link}"
done > $log_file




