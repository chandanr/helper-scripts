#include <uapi/linux/ptrace.h>
#include <linux/sched.h>

struct data {
	u64 ino;
	u64 ts;
	u64 dio_list_len;
};

BPF_RINGBUF_OUTPUT(events, 8);

int trace_xfs_end_dio(struct pt_regs *ctx)
{
	struct data data;
	u64 rbp = ctx->bp;
	u64 xfs_inode;
	u64 ino;
	int dio_list_len;
	long ret;

	ret = bpf_probe_read_kernel(&xfs_inode, sizeof(xfs_inode),
				    (void *)(rbp - 0x70));

	ret = bpf_probe_read_kernel(&ino, sizeof(ino),
		(void *)(xfs_inode + 32));

	ret = bpf_probe_read_kernel(&dio_list_len, sizeof(dio_list_len),
				    (void *)(rbp - 0x7c));

	data.ino = ino;
	data.dio_list_len = dio_list_len;
	data.ts = bpf_ktime_get_ns();

	events.ringbuf_output(&data, sizeof(data), BPF_RB_FORCE_WAKEUP);

	return 0;
}
