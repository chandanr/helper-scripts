#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/ioctl.h>

#include <xfs/xfs.h>

#define CMD_BUF_SIZE 100

int main(int argc, char *argv[])
{
	struct xfs_swapext sx;
	struct xfs_fsop_bulkreq bulkreq = { 0 };
	struct stat stat;
	char cmd[CMD_BUF_SIZE];
	int sourcefd, donorfd;
	int error;

	if (argc != 4) {
		fprintf(stderr, "Usage: %s <source> <donor> <shortdev>\n",
				argv[0]);
		goto out1;
	}

	sourcefd = open(argv[1], O_RDWR);
	if (sourcefd == -1) {
		perror("open");
		goto out1;
	}

	error = remove(argv[1]);
	if (error == -1) {
		perror("remove");
		goto out2;
	}

	error = fsync(sourcefd);
	if (error == -1) {
		perror("syncfs");
		goto out2;
	}

	error = fstat(sourcefd, &stat);
	if (error) {
		perror("fstat");
		goto out2;
	}

	bulkreq.lastip = (__u64 *)&(stat.st_ino);
	bulkreq.icount = 1;
	bulkreq.ubuffer = &sx.sx_stat;
	error = ioctl(sourcefd, XFS_IOC_FSBULKSTAT_SINGLE, &bulkreq);
	if (error == -1) {
		perror("ioctl");
		goto out2;
	}

	donorfd = open(argv[2], O_RDWR);
	if (donorfd == -1) {
		perror("open");
		goto out2;
	}

	sx.sx_version = XFS_SX_VERSION;
	sx.sx_fdtarget = sourcefd;
	sx.sx_fdtmp = donorfd;
	sx.sx_offset = 0;
	sx.sx_length = stat.st_size;

	snprintf(cmd, CMD_BUF_SIZE,
			"echo 1 > /sys/fs/xfs/%s/errortag/bmap_finish_one",
			argv[3]);
	system(cmd);

	error = ioctl(sourcefd, XFS_IOC_SWAPEXT, &sx);
	if (error) {
		perror("swapext");
		goto out3;
	}

	close(donorfd);

	close(sourcefd);

	exit(0);

out3:
	close(donorfd);
out2:
	close(sourcefd);
out1:
	exit(1);
}
