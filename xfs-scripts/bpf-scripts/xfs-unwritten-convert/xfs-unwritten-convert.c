#include <uapi/linux/ptrace.h>
#include <linux/sched.h>

BPF_ARRAY(nr_conversions, u64, 1);

int trace_xfs_unwritten_convert(struct pt_regs *ctx)
{
	u64 *valp, val;
	int zero = 0;

	valp = nr_conversions.lookup(&zero);
	if (valp == NULL)
		val = 1;
	else
		val = *valp + 1;

	nr_conversions.update(&zero, &val);

	return 0;
}
