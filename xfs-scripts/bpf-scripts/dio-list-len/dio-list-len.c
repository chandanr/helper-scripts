#include <uapi/linux/ptrace.h>
#include <linux/sched.h>

BPF_ARRAY(dio_list_len, u64, 16);

int trace_xfs_end_dio(struct pt_regs *ctx)
{
	u64 rbp = ctx->bp;
	u64 inode;
	u64 ino;
	u64 *valp, val;
	int nr_entries;
	long ret;

	ret = bpf_probe_read_kernel(&inode, sizeof(inode),
		(void *)(rbp - 0x70));

	ret = bpf_probe_read_kernel(&ino, sizeof(ino),
		(void *)(inode + 32));

	ret = bpf_probe_read_kernel(&nr_entries, sizeof(nr_entries),
				    (void *)(rbp - 0x7c));
	--nr_entries;
	valp = dio_list_len.lookup(&nr_entries);
	if (valp == NULL) {
	  val = 1;
	} else {
	  val = *valp + 1;
	}
	dio_list_len.update(&nr_entries, &val);

	return 0;
}
