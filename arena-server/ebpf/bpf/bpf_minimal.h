#ifndef __PIT_BPF_MINIMAL_H
#define __PIT_BPF_MINIMAL_H

#include <linux/types.h>
#include <linux/bpf.h>

#define SEC(name) __attribute__((section(name), used))
#undef __always_inline
#define __always_inline inline __attribute__((always_inline))

#define __uint(name, val) int (*name)[val]
#define __type(name, val) typeof(val) *name

/* Standard BPF helper function pointers (frozen Linux UAPI ABI) */
static void *(*bpf_map_lookup_elem)(void *map, const void *key) =
    (void *)BPF_FUNC_map_lookup_elem;
static long (*bpf_map_update_elem)(void *map, const void *key, const void *value, __u64 flags) =
    (void *)BPF_FUNC_map_update_elem;
static long (*bpf_map_delete_elem)(void *map, const void *key) =
    (void *)BPF_FUNC_map_delete_elem;
static __u64 (*bpf_ktime_get_ns)(void) =
    (void *)BPF_FUNC_ktime_get_ns;
static __u64 (*bpf_get_current_pid_tgid)(void) =
    (void *)BPF_FUNC_get_current_pid_tgid;
static __u64 (*bpf_get_current_uid_gid)(void) =
    (void *)BPF_FUNC_get_current_uid_gid;
static long (*bpf_get_current_comm)(void *buf, __u32 size_of_buf) =
    (void *)BPF_FUNC_get_current_comm;
static __u64 (*bpf_get_current_task)(void) =
    (void *)BPF_FUNC_get_current_task;
static __u64 (*bpf_get_current_cgroup_id)(void) =
    (void *)BPF_FUNC_get_current_cgroup_id;
static long (*bpf_probe_read_user)(void *dst, __u32 size, const void *unsafe_ptr) =
    (void *)BPF_FUNC_probe_read_user;
static long (*bpf_probe_read_kernel)(void *dst, __u32 size, const void *unsafe_ptr) =
    (void *)BPF_FUNC_probe_read_kernel;
static long (*bpf_probe_read_user_str)(void *dst, __u32 size, const void *unsafe_ptr) =
    (void *)BPF_FUNC_probe_read_user_str;
static long (*bpf_probe_read_kernel_str)(void *dst, __u32 size, const void *unsafe_ptr) =
    (void *)BPF_FUNC_probe_read_kernel_str;
static void *(*bpf_ringbuf_reserve)(void *ringbuf, __u64 size, __u64 flags) =
    (void *)BPF_FUNC_ringbuf_reserve;
static void (*bpf_ringbuf_submit)(void *data, __u64 flags) =
    (void *)BPF_FUNC_ringbuf_submit;
static void (*bpf_ringbuf_discard)(void *data, __u64 flags) =
    (void *)BPF_FUNC_ringbuf_discard;

/* x86_64 pt_regs for kprobes & uprobes */
struct pt_regs {
    unsigned long r15;
    unsigned long r14;
    unsigned long r13;
    unsigned long r12;
    unsigned long bp;
    unsigned long bx;
    unsigned long r11;
    unsigned long r10;
    unsigned long r9;
    unsigned long r8;
    unsigned long ax;
    unsigned long cx;
    unsigned long dx;
    unsigned long si;
    unsigned long di;
    unsigned long orig_ax;
    unsigned long ip;
    unsigned long cs;
    unsigned long flags;
    unsigned long sp;
    unsigned long ss;
};

#define PT_REGS_PARM1(x) ((x)->di)
#define PT_REGS_PARM2(x) ((x)->si)
#define PT_REGS_PARM3(x) ((x)->dx)
#define PT_REGS_PARM4(x) ((x)->cx)
#define PT_REGS_RC(x)    ((x)->ax)

/* Minimal CO-RE kernel structures (resolved via /sys/kernel/btf/vmlinux) */
typedef struct {
    unsigned int val;
} __attribute__((preserve_access_index)) kuid_t;

struct cred {
    kuid_t uid;
    kuid_t euid;
} __attribute__((preserve_access_index));

struct task_struct {
    struct task_struct *real_parent;
    int tgid;
    char comm[16];
} __attribute__((preserve_access_index));

/* Socket constants & structures */
#define AF_INET  2
#define AF_INET6 10

struct sockaddr_in_bpf {
    __u16 sin_family;
    __be16 sin_port;
    __u32 sin_addr;
    __u8  sin_zero[8];
};

struct sockaddr_in6_bpf {
    __u16 sin6_family;
    __be16 sin6_port;
    __u32 sin6_flowinfo;
    __u32 sin6_addr[4];
    __u32 sin6_scope_id;
};

/* Openat flags (x86_64 Linux) */
#define O_WRONLY_BPF 00000001
#define O_RDWR_BPF   00000002
#define O_CREAT_BPF  00000100
#define O_TRUNC_BPF  00001000
#define O_APPEND_BPF 00002000

#endif /* __PIT_BPF_MINIMAL_H */
