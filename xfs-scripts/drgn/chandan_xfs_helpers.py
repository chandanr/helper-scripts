import drgn
from drgn import NULL, Object, cast, container_of, execscript, offsetof, reinterpret, sizeof
from drgn.helpers.common import *
from drgn.helpers.linux import *

def xfs_task_to_buf_lock_owner_pid(prog, pid):
    task = find_task(prog, pid)
    trace = prog.stack_trace(task)

    if len(trace) < 7 or not "xfs_buf_lock" in trace[7]:
        print("Trace does not have xfs_buf calls")
        print(f"{trace}")
        return None

    xfs_buf = trace[7]['bp']
    daddr = xfs_buf.__b_map.bm_bn
    xfs_trans = Object(prog, "struct xfs_trans",
                       address=xfs_buf.b_transp)
    xlog_ticket = Object(prog, "struct xlog_ticket",
                         address=xfs_trans.t_ticket)
    xfs_tid = xlog_ticket.t_tid

    task_struct = Object(prog, "struct task_struct",
                         address=xlog_ticket.t_task)

    task_pid = task_struct.pid
    task_comm = task_struct.comm

    print(f"daddr = {daddr}, task pid = {task_pid}, task command = {task_comm}")
