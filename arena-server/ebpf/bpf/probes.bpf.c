//go:build ignore

#include "bpf_minimal.h"

char LICENSE[] SEC("license") = "Dual BSD/GPL";

#define EVENT_EXECVE    1
#define EVENT_CONNECT   2
#define EVENT_OPENAT    3
#define EVENT_PRIVESC   4
#define EVENT_SSL_WRITE 5
#define EVENT_SSL_READ  6

#define PRIVESC_SETUID      1
#define PRIVESC_SETRESUID   2
#define PRIVESC_COMMIT_CRED 3

#define SSL_SUB_WRITE 1
#define SSL_SUB_READ  2

#define MAX_FILENAME_LEN 192
#define MAX_PAYLOAD_LEN  512

struct pit_sensor_cfg {
    __u32 sensor_tgid;
    __u32 pad;
    __u64 host_root_cgroup_id;
};

/* Zero-lock 64-byte (single L1 cacheline) per-CPU kernel telemetry counters */
struct pit_bpf_stats {
    __u64 syscalls_entered;
    __u64 filtered_in_kernel;
    __u64 ringbuf_submitted;
    __u64 ringbuf_drops;
    __u64 execve_submitted;
    __u64 connect_submitted;
    __u64 openat_submitted;
    __u64 security_submitted;
};

_Static_assert(sizeof(struct pit_bpf_stats) == 64, "pit_bpf_stats must fit in one 64B cacheline");

struct pit_raw_event {
    __u64 ts_ns;
    __u64 cgroup_id;
    __u32 pid;
    __u32 tid;
    __u32 uid;
    __u32 ppid;
    __u32 target_uid;
    __u32 flags;
    __s32 dfd;
    __u32 dst_ip;
    __u16 dst_port;
    __u16 payload_len;
    __u8  event_type;
    __u8  sub_type;
    __u8  arg_count;
    __u8  pad0;
    char  comm[16];
    char  parent_comm[16];
    char  filename[MAX_FILENAME_LEN];
    char  argv0[64];
    char  argv1[64];
    char  argv2[128];
    char  argv3[128];
    __u8  payload[MAX_PAYLOAD_LEN];
    __u64 duration_ns;
};

_Static_assert(sizeof(struct pit_raw_event) == 1184, "pit_raw_event size must be 1184 bytes");

struct exec_scratch {
    __u64 enter_ts_ns;
    __u8  arg_count;
    char  invoker_comm[16];
    char  filename[MAX_FILENAME_LEN];
    char  argv0[64];
    char  argv1[64];
    char  argv2[128];
    char  argv3[128];
};

struct ssl_read_stash {
    __u64 enter_ts_ns;
    __u64 buf_ptr;
    __u64 readbytes_ptr;
};

/* BPF Maps */
struct {
    __uint(type, BPF_MAP_TYPE_RINGBUF);
    __uint(max_entries, 4 * 1024 * 1024); /* 4 MB lock-free RingBuffer */
} events SEC(".maps");

struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, struct pit_sensor_cfg);
} sensor_config SEC(".maps");

struct {
    __uint(type, BPF_MAP_TYPE_PERCPU_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, struct pit_bpf_stats);
} pit_perf_stats SEC(".maps");

struct {
    __uint(type, BPF_MAP_TYPE_PERCPU_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, struct exec_scratch);
} exec_zero_map SEC(".maps");

struct {
    __uint(type, BPF_MAP_TYPE_LRU_HASH);
    __uint(max_entries, 4096);
    __type(key, __u64);
    __type(value, struct exec_scratch);
} exec_inflight SEC(".maps");

struct {
    __uint(type, BPF_MAP_TYPE_LRU_HASH);
    __uint(max_entries, 4096);
    __type(key, __u64);
    __type(value, struct ssl_read_stash);
} ssl_read_args SEC(".maps");

/* Tracepoint Context Structs (exact Linux x86_64 tracepoint ABI) */
struct tp_sys_enter_execve {
    __u64 common_pad;
    int __syscall_nr;
    int pad;
    const char *filename;
    const char *const *argv;
    const char *const *envp;
};

struct tp_sys_exit_execve {
    __u64 common_pad;
    int __syscall_nr;
    int pad;
    long ret;
};

struct tp_sys_enter_connect {
    __u64 common_pad;
    int __syscall_nr;
    int pad;
    unsigned long fd;
    const void *uservaddr;
    unsigned long addrlen;
};

struct tp_sys_enter_openat {
    __u64 common_pad;
    int __syscall_nr;
    int pad;
    long dfd;
    const char *filename;
    unsigned long flags;
    unsigned long mode;
};

struct tp_sys_enter_setuid {
    __u64 common_pad;
    int __syscall_nr;
    int pad;
    unsigned long uid;
};

struct tp_sys_enter_setresuid {
    __u64 common_pad;
    int __syscall_nr;
    int pad;
    unsigned long ruid;
    unsigned long euid;
    unsigned long suid;
};

static __always_inline struct pit_bpf_stats *get_perf_stats(void) {
    __u32 key = 0;
    return bpf_map_lookup_elem(&pit_perf_stats, &key);
}

static __always_inline int should_ignore_self(__u32 tgid, __u64 cgroup_id) {
    __u32 key = 0;
    struct pit_sensor_cfg *cfg = bpf_map_lookup_elem(&sensor_config, &key);
    if (!cfg)
        return 0;
    if (cfg->sensor_tgid != 0 && tgid == cfg->sensor_tgid)
        return 1;
    if (cfg->host_root_cgroup_id != 0 && cgroup_id == cfg->host_root_cgroup_id)
        return 1;
    return 0;
}

static __always_inline void populate_common(struct pit_raw_event *e, __u8 ev_type, __u64 pid_tgid, __u64 cgroup_id) {
    e->ts_ns = bpf_ktime_get_ns();
    e->cgroup_id = cgroup_id;
    e->pid = (__u32)(pid_tgid >> 32);
    e->tid = (__u32)pid_tgid;
    e->uid = (__u32)bpf_get_current_uid_gid();
    e->event_type = ev_type;
    bpf_get_current_comm(e->comm, sizeof(e->comm));

    struct task_struct *task = (struct task_struct *)bpf_get_current_task();
    if (task) {
        struct task_struct *parent = 0;
        bpf_probe_read_kernel(&parent, sizeof(parent), &task->real_parent);
        if (parent) {
            int ppid = 0;
            bpf_probe_read_kernel(&ppid, sizeof(ppid), &parent->tgid);
            e->ppid = (__u32)ppid;
            bpf_probe_read_kernel_str(e->parent_comm, sizeof(e->parent_comm), parent->comm);
        }
    }
}

/* 1a. tracepoint/syscalls/sys_enter_execve */
SEC("tracepoint/syscalls/sys_enter_execve")
int handle_sys_enter_execve(struct tp_sys_enter_execve *ctx) {
    struct pit_bpf_stats *st = get_perf_stats();
    if (st)
        st->syscalls_entered++;

    __u64 pid_tgid = bpf_get_current_pid_tgid();
    __u32 tgid = (__u32)(pid_tgid >> 32);
    __u64 cgroup_id = bpf_get_current_cgroup_id();
    if (should_ignore_self(tgid, cgroup_id)) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    __u32 zero_key = 0;
    struct exec_scratch *zero = bpf_map_lookup_elem(&exec_zero_map, &zero_key);
    if (!zero) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    if (bpf_map_update_elem(&exec_inflight, &pid_tgid, zero, BPF_ANY) != 0) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    struct exec_scratch *sc = bpf_map_lookup_elem(&exec_inflight, &pid_tgid);
    if (!sc) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    sc->enter_ts_ns = bpf_ktime_get_ns();
    bpf_get_current_comm(sc->invoker_comm, sizeof(sc->invoker_comm));
    bpf_probe_read_user_str(sc->filename, sizeof(sc->filename), ctx->filename);

    const char *const *argv = ctx->argv;
    if (argv) {
        const char *argp = 0;
        if (bpf_probe_read_user(&argp, sizeof(argp), &argv[0]) == 0 && argp) {
            bpf_probe_read_user_str(sc->argv0, sizeof(sc->argv0), argp);
            sc->arg_count = 1;

            argp = 0;
            if (bpf_probe_read_user(&argp, sizeof(argp), &argv[1]) == 0 && argp) {
                bpf_probe_read_user_str(sc->argv1, sizeof(sc->argv1), argp);
                sc->arg_count = 2;

                argp = 0;
                if (bpf_probe_read_user(&argp, sizeof(argp), &argv[2]) == 0 && argp) {
                    bpf_probe_read_user_str(sc->argv2, sizeof(sc->argv2), argp);
                    sc->arg_count = 3;

                    argp = 0;
                    if (bpf_probe_read_user(&argp, sizeof(argp), &argv[3]) == 0 && argp) {
                        bpf_probe_read_user_str(sc->argv3, sizeof(sc->argv3), argp);
                        sc->arg_count = 4;
                    }
                }
            }
        }
    }

    return 0;
}

/* 1b. tracepoint/syscalls/sys_exit_execve (filters out failed -ENOENT PATH probes) */
SEC("tracepoint/syscalls/sys_exit_execve")
int handle_sys_exit_execve(struct tp_sys_exit_execve *ctx) {
    __u64 pid_tgid = bpf_get_current_pid_tgid();
    struct exec_scratch *sc = bpf_map_lookup_elem(&exec_inflight, &pid_tgid);
    if (!sc)
        return 0;

    struct pit_bpf_stats *st = get_perf_stats();
    if (ctx->ret < 0) {
        if (st)
            st->filtered_in_kernel++;
        bpf_map_delete_elem(&exec_inflight, &pid_tgid);
        return 0;
    }

    __u64 cgroup_id = bpf_get_current_cgroup_id();
    struct pit_raw_event *e = bpf_ringbuf_reserve(&events, sizeof(*e), 0);
    if (!e) {
        if (st)
            st->ringbuf_drops++;
        bpf_map_delete_elem(&exec_inflight, &pid_tgid);
        return 0;
    }

    __builtin_memset(e, 0, 88);
    populate_common(e, EVENT_EXECVE, pid_tgid, cgroup_id);
    e->duration_ns = (sc->enter_ts_ns > 0 && e->ts_ns > sc->enter_ts_ns) ? (e->ts_ns - sc->enter_ts_ns) : 0;
    if (e->parent_comm[0] == '\0') {
        __builtin_memcpy(e->parent_comm, sc->invoker_comm, sizeof(e->parent_comm));
    }
    e->arg_count = sc->arg_count;
    __builtin_memcpy(e->filename, sc->filename, sizeof(e->filename));
    __builtin_memcpy(e->argv0, sc->argv0, sizeof(e->argv0));
    __builtin_memcpy(e->argv1, sc->argv1, sizeof(e->argv1));
    __builtin_memcpy(e->argv2, sc->argv2, sizeof(e->argv2));
    __builtin_memcpy(e->argv3, sc->argv3, sizeof(e->argv3));
    e->payload[0] = 0;

    bpf_map_delete_elem(&exec_inflight, &pid_tgid);
    bpf_ringbuf_submit(e, 0);
    if (st) {
        st->ringbuf_submitted++;
        st->execve_submitted++;
    }
    return 0;
}

/* 2. tracepoint/syscalls/sys_enter_connect */
SEC("tracepoint/syscalls/sys_enter_connect")
int handle_sys_enter_connect(struct tp_sys_enter_connect *ctx) {
    struct pit_bpf_stats *st = get_perf_stats();
    if (st)
        st->syscalls_entered++;

    __u64 pid_tgid = bpf_get_current_pid_tgid();
    __u32 tgid = (__u32)(pid_tgid >> 32);
    __u64 cgroup_id = bpf_get_current_cgroup_id();
    if (should_ignore_self(tgid, cgroup_id)) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    const void *uaddr = ctx->uservaddr;
    if (!uaddr || ctx->addrlen < 16) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    __u16 family = 0;
    if (bpf_probe_read_user(&family, sizeof(family), uaddr) != 0) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    __u32 dst_ip = 0;
    __u16 dst_port = 0;
    __u8 sub_family = 0;

    if (family == AF_INET) {
        struct sockaddr_in_bpf sin = {};
        if (bpf_probe_read_user(&sin, sizeof(sin), uaddr) != 0) {
            if (st)
                st->filtered_in_kernel++;
            return 0;
        }
        dst_ip = sin.sin_addr;
        dst_port = __builtin_bswap16(sin.sin_port);
        sub_family = AF_INET;
    } else if (family == AF_INET6 && ctx->addrlen >= sizeof(struct sockaddr_in6_bpf)) {
        struct sockaddr_in6_bpf sin6 = {};
        if (bpf_probe_read_user(&sin6, sizeof(sin6), uaddr) != 0) {
            if (st)
                st->filtered_in_kernel++;
            return 0;
        }
        /* Match IPv4-mapped IPv6 ::ffff:a.b.c.d */
        if (sin6.sin6_addr[0] == 0 && sin6.sin6_addr[1] == 0 &&
            sin6.sin6_addr[2] == __builtin_bswap32(0x0000ffff)) {
            dst_ip = sin6.sin6_addr[3];
            dst_port = __builtin_bswap16(sin6.sin6_port);
            sub_family = AF_INET6;
        } else {
            if (st)
                st->filtered_in_kernel++;
            return 0;
        }
    } else {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    if (dst_port == 0 || (dst_ip & 0xff) == 127) {
        /* Ignore port 0 and 127.0.0.0/8 loopback (e.g. Docker internal DNS 127.0.0.11:53) */
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    struct pit_raw_event *e = bpf_ringbuf_reserve(&events, sizeof(*e), 0);
    if (!e) {
        if (st)
            st->ringbuf_drops++;
        return 0;
    }

    __builtin_memset(e, 0, 96);
    populate_common(e, EVENT_CONNECT, pid_tgid, cgroup_id);
    e->sub_type = sub_family;
    e->dst_ip = dst_ip;
    e->dst_port = dst_port;
    e->argv0[0] = 0;
    e->payload[0] = 0;
    e->duration_ns = 0;

    bpf_ringbuf_submit(e, 0);
    if (st) {
        st->ringbuf_submitted++;
        st->connect_submitted++;
    }
    return 0;
}

static __always_inline int is_ignored_prefix(const char *p) {
    /* /proc/, /sys/, /dev/, /lib/, /run/, /usr/lib/, /etc/ld.so */
    if (p[0] != '/')
        return 0;
    if (p[1] == 'p' && p[2] == 'r' && p[3] == 'o' && p[4] == 'c' && p[5] == '/')
        return 1;
    if (p[1] == 's' && p[2] == 'y' && p[3] == 's' && p[4] == '/')
        return 1;
    if (p[1] == 'd' && p[2] == 'e' && p[3] == 'v' && p[4] == '/')
        return 1;
    if (p[1] == 'l' && p[2] == 'i' && p[3] == 'b')
        return 1;
    if (p[1] == 'r' && p[2] == 'u' && p[3] == 'n' && p[4] == '/')
        return 1;
    if (p[1] == 'u' && p[2] == 's' && p[3] == 'r' && p[4] == '/' &&
        p[5] == 'l' && p[6] == 'i' && p[7] == 'b')
        return 1;
    if (p[1] == 'e' && p[2] == 't' && p[3] == 'c' && p[4] == '/' &&
        p[5] == 'l' && p[6] == 'd' && p[7] == '.')
        return 1;
    return 0;
}

static __always_inline int should_forward_openat(const char *p, __u32 flags) {
    if (is_ignored_prefix(p))
        return 0;

    /* Forward all non-virtual file writes for NANO_PATCH_WELD / beacon detection */
    if (flags & (O_WRONLY_BPF | O_RDWR_BPF | O_CREAT_BPF | O_TRUNC_BPF | O_APPEND_BPF))
        return 1;

    /* Target directories: /app/, /pit/, /var/www/, /srv/, /flag, /etc/shadow */
    if (p[0] == '/') {
        if (p[1] == 'a' && p[2] == 'p' && p[3] == 'p' && p[4] == '/')
            return 1;
        if (p[1] == 'p' && p[2] == 'i' && p[3] == 't' && (p[4] == '/' || p[4] == '\0'))
            return 1;
        if (p[1] == 's' && p[2] == 'r' && p[3] == 'v' && p[4] == '/')
            return 1;
        if (p[1] == 'v' && p[2] == 'a' && p[3] == 'r' && p[4] == '/' &&
            p[5] == 'w' && p[6] == 'w' && p[7] == 'w' && p[8] == '/')
            return 1;
        if (p[1] == 'f' && p[2] == 'l' && p[3] == 'a' && p[4] == 'g')
            return 1;
        if (p[1] == 'e' && p[2] == 't' && p[3] == 'c' && p[4] == '/' &&
            p[5] == 's' && p[6] == 'h' && p[7] == 'a' && p[8] == 'd' && p[9] == 'o' && p[10] == 'w')
            return 1;
    }

    /* Bounded scan for sensitive files (flag, shadow, .env, id_rsa, king_beacon) & source extensions */
    for (int i = 0; i < 160; i++) {
        char c = p[i];
        if (c == '\0')
            break;
        if (c == 'f' && p[i + 1] == 'l' && p[i + 2] == 'a' && p[i + 3] == 'g')
            return 1;
        if (c == 's' && p[i + 1] == 'h' && p[i + 2] == 'a' && p[i + 3] == 'd' &&
            p[i + 4] == 'o' && p[i + 5] == 'w')
            return 1;
        if (c == 'i' && p[i + 1] == 'd' && p[i + 2] == '_' && p[i + 3] == 'r' &&
            p[i + 4] == 's' && p[i + 5] == 'a')
            return 1;
        if (c == 'k' && p[i + 1] == 'i' && p[i + 2] == 'n' && p[i + 3] == 'g' &&
            p[i + 4] == '_' && p[i + 5] == 'b' && p[i + 6] == 'e' && p[i + 7] == 'a')
            return 1;
        if (c == '.') {
            if (p[i + 1] == 'e' && p[i + 2] == 'n' && p[i + 3] == 'v' &&
                (p[i + 4] == '\0' || p[i + 4] == '.'))
                return 1;
            if (p[i + 1] == 'p' && p[i + 2] == 'y' && p[i + 3] == '\0')
                return 1;
            if (p[i + 1] == 'j' && p[i + 2] == 's' && p[i + 3] == '\0')
                return 1;
            if (p[i + 1] == 't' && p[i + 2] == 's' && p[i + 3] == '\0')
                return 1;
            if (p[i + 1] == 'g' && p[i + 2] == 'o' && p[i + 3] == '\0')
                return 1;
            if (p[i + 1] == 'p' && p[i + 2] == 'h' && p[i + 3] == 'p' && p[i + 4] == '\0')
                return 1;
            if (p[i + 1] == 'j' && p[i + 2] == 'a' && p[i + 3] == 'v' && p[i + 4] == 'a' && p[i + 5] == '\0')
                return 1;
            if (p[i + 1] == 'c' && p[i + 2] == 'o' && p[i + 3] == 'n' && p[i + 4] == 'f' && p[i + 5] == '\0')
                return 1;
        }
    }
    return 0;
}

/* 3. tracepoint/syscalls/sys_enter_openat */
SEC("tracepoint/syscalls/sys_enter_openat")
int handle_sys_enter_openat(struct tp_sys_enter_openat *ctx) {
    struct pit_bpf_stats *st = get_perf_stats();
    if (st)
        st->syscalls_entered++;

    __u64 pid_tgid = bpf_get_current_pid_tgid();
    __u32 tgid = (__u32)(pid_tgid >> 32);
    __u64 cgroup_id = bpf_get_current_cgroup_id();
    if (should_ignore_self(tgid, cgroup_id)) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    char fname[MAX_FILENAME_LEN] = {};
    long n = bpf_probe_read_user_str(fname, sizeof(fname), ctx->filename);
    if (n <= 1) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    __u32 flags = (__u32)ctx->flags;
    if (!should_forward_openat(fname, flags)) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    struct pit_raw_event *e = bpf_ringbuf_reserve(&events, sizeof(*e), 0);
    if (!e) {
        if (st)
            st->ringbuf_drops++;
        return 0;
    }

    __builtin_memset(e, 0, 88);
    populate_common(e, EVENT_OPENAT, pid_tgid, cgroup_id);
    e->dfd = (__s32)ctx->dfd;
    e->flags = flags;
    __builtin_memcpy(e->filename, fname, sizeof(e->filename));
    e->argv0[0] = 0;
    e->payload[0] = 0;
    e->duration_ns = 0;

    bpf_ringbuf_submit(e, 0);
    if (st) {
        st->ringbuf_submitted++;
        st->openat_submitted++;
    }
    return 0;
}

static __always_inline int emit_privesc(__u8 sub_type, __u32 target_uid) {
    struct pit_bpf_stats *st = get_perf_stats();
    __u64 pid_tgid = bpf_get_current_pid_tgid();
    __u32 tgid = (__u32)(pid_tgid >> 32);
    __u64 cgroup_id = bpf_get_current_cgroup_id();
    if (should_ignore_self(tgid, cgroup_id)) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    __u32 cur_uid = (__u32)bpf_get_current_uid_gid();
    if (cur_uid == 0 || target_uid != 0) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    struct pit_raw_event *e = bpf_ringbuf_reserve(&events, sizeof(*e), 0);
    if (!e) {
        if (st)
            st->ringbuf_drops++;
        return 0;
    }

    __builtin_memset(e, 0, 96);
    populate_common(e, EVENT_PRIVESC, pid_tgid, cgroup_id);
    e->sub_type = sub_type;
    e->target_uid = target_uid;
    e->argv0[0] = 0;
    e->payload[0] = 0;
    e->duration_ns = 0;

    bpf_ringbuf_submit(e, 0);
    if (st) {
        st->ringbuf_submitted++;
        st->security_submitted++;
    }
    return 0;
}

/* 4a. tracepoint/syscalls/sys_enter_setuid */
SEC("tracepoint/syscalls/sys_enter_setuid")
int handle_sys_enter_setuid(struct tp_sys_enter_setuid *ctx) {
    struct pit_bpf_stats *st = get_perf_stats();
    if (st)
        st->syscalls_entered++;
    return emit_privesc(PRIVESC_SETUID, (__u32)ctx->uid);
}

/* 4b. tracepoint/syscalls/sys_enter_setresuid */
SEC("tracepoint/syscalls/sys_enter_setresuid")
int handle_sys_enter_setresuid(struct tp_sys_enter_setresuid *ctx) {
    struct pit_bpf_stats *st = get_perf_stats();
    if (st)
        st->syscalls_entered++;

    __u32 ruid = (__u32)ctx->ruid;
    __u32 euid = (__u32)ctx->euid;
    __u32 suid = (__u32)ctx->suid;
    if (ruid == 0 || euid == 0 || suid == 0)
        return emit_privesc(PRIVESC_SETRESUID, 0);

    if (st)
        st->filtered_in_kernel++;
    return 0;
}

/* 4c. kprobe/commit_creds (CO-RE via /sys/kernel/btf/vmlinux) */
SEC("kprobe/commit_creds")
int handle_commit_creds(struct pt_regs *ctx) {
    struct pit_bpf_stats *st = get_perf_stats();
    if (st)
        st->syscalls_entered++;

    struct cred *new_cred = (struct cred *)PT_REGS_PARM1(ctx);
    if (!new_cred) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    __u32 cur_uid = (__u32)bpf_get_current_uid_gid();
    if (cur_uid == 0) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    __u32 new_uid = 1;
    __u32 new_euid = 1;
    bpf_probe_read_kernel(&new_uid, sizeof(new_uid), &new_cred->uid.val);
    bpf_probe_read_kernel(&new_euid, sizeof(new_euid), &new_cred->euid.val);

    if (new_uid == 0 || new_euid == 0)
        return emit_privesc(PRIVESC_COMMIT_CRED, 0);

    if (st)
        st->filtered_in_kernel++;
    return 0;
}

static __always_inline int emit_ssl_buf(__u8 ev_type, __u8 sub_type, const void *buf, __u64 raw_len, __u64 enter_ts_ns) {
    struct pit_bpf_stats *st = get_perf_stats();
    if (st)
        st->syscalls_entered++;

    if (!buf || raw_len == 0) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    __u64 pid_tgid = bpf_get_current_pid_tgid();
    __u32 tgid = (__u32)(pid_tgid >> 32);
    __u64 cgroup_id = bpf_get_current_cgroup_id();
    if (should_ignore_self(tgid, cgroup_id)) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    __u64 copy_len = raw_len >= MAX_PAYLOAD_LEN ? (MAX_PAYLOAD_LEN - 1) : raw_len;
    if (copy_len == 0) {
        if (st)
            st->filtered_in_kernel++;
        return 0;
    }

    struct pit_raw_event *e = bpf_ringbuf_reserve(&events, sizeof(*e), 0);
    if (!e) {
        if (st)
            st->ringbuf_drops++;
        return 0;
    }

    __builtin_memset(e, 0, 96);
    populate_common(e, ev_type, pid_tgid, cgroup_id);
    e->sub_type = sub_type;
    e->argv0[0] = 0;
    e->duration_ns = (enter_ts_ns > 0 && e->ts_ns > enter_ts_ns) ? (e->ts_ns - enter_ts_ns) : 0;

    /* Un-eliminable 64-bit bitwise mask barrier right before helper call for Linux 5.10-6.x BPF verifiers */
    asm volatile("%0 &= 0x1ff\n" : "+r"(copy_len));
    e->payload_len = (__u16)copy_len;
    if (copy_len > 0) {
        if (bpf_probe_read_user(e->payload, (__u32)copy_len, buf) != 0) {
            if (st)
                st->filtered_in_kernel++;
            bpf_ringbuf_discard(e, 0);
            return 0;
        }
        e->payload[copy_len & 0x1ff] = 0;
    }

    bpf_ringbuf_submit(e, 0);
    if (st) {
        st->ringbuf_submitted++;
        st->security_submitted++;
    }
    return 0;
}

/* 5a. uprobe/SSL_write & uprobe/SSL_write_ex */
SEC("uprobe/SSL_write")
int handle_ssl_write(struct pt_regs *ctx) {
    const void *buf = (const void *)PT_REGS_PARM2(ctx);
    int num = (int)PT_REGS_PARM3(ctx);
    if (num <= 0)
        return 0;
    return emit_ssl_buf(EVENT_SSL_WRITE, SSL_SUB_WRITE, buf, (__u64)num, 0);
}

SEC("uprobe/SSL_write_ex")
int handle_ssl_write_ex(struct pt_regs *ctx) {
    const void *buf = (const void *)PT_REGS_PARM2(ctx);
    __u64 num = (__u64)PT_REGS_PARM3(ctx);
    return emit_ssl_buf(EVENT_SSL_WRITE, SSL_SUB_WRITE, buf, num, 0);
}

/* 5b. uprobe/SSL_read + uretprobe/SSL_read */
SEC("uprobe/SSL_read")
int handle_ssl_read_enter(struct pt_regs *ctx) {
    __u64 pid_tgid = bpf_get_current_pid_tgid();
    __u32 tgid = (__u32)(pid_tgid >> 32);
    __u64 cgroup_id = bpf_get_current_cgroup_id();
    if (should_ignore_self(tgid, cgroup_id))
        return 0;

    struct ssl_read_stash st = {};
    st.enter_ts_ns = bpf_ktime_get_ns();
    st.buf_ptr = (__u64)PT_REGS_PARM2(ctx);
    st.readbytes_ptr = 0;
    if (st.buf_ptr == 0)
        return 0;
    bpf_map_update_elem(&ssl_read_args, &pid_tgid, &st, BPF_ANY);
    return 0;
}

SEC("uretprobe/SSL_read")
int handle_ssl_read_exit(struct pt_regs *ctx) {
    __u64 pid_tgid = bpf_get_current_pid_tgid();
    struct ssl_read_stash *st = bpf_map_lookup_elem(&ssl_read_args, &pid_tgid);
    if (!st)
        return 0;

    __u64 enter_ts_ns = st->enter_ts_ns;
    __u64 buf_ptr = st->buf_ptr;
    bpf_map_delete_elem(&ssl_read_args, &pid_tgid);

    int ret = (int)PT_REGS_RC(ctx);
    if (ret <= 0)
        return 0;

    return emit_ssl_buf(EVENT_SSL_READ, SSL_SUB_READ, (const void *)buf_ptr, (__u64)ret, enter_ts_ns);
}

/* 5c. uprobe/SSL_read_ex + uretprobe/SSL_read_ex */
SEC("uprobe/SSL_read_ex")
int handle_ssl_read_ex_enter(struct pt_regs *ctx) {
    __u64 pid_tgid = bpf_get_current_pid_tgid();
    __u32 tgid = (__u32)(pid_tgid >> 32);
    __u64 cgroup_id = bpf_get_current_cgroup_id();
    if (should_ignore_self(tgid, cgroup_id))
        return 0;

    struct ssl_read_stash st = {};
    st.enter_ts_ns = bpf_ktime_get_ns();
    st.buf_ptr = (__u64)PT_REGS_PARM2(ctx);
    st.readbytes_ptr = (__u64)PT_REGS_PARM4(ctx);
    if (st.buf_ptr == 0 || st.readbytes_ptr == 0)
        return 0;
    bpf_map_update_elem(&ssl_read_args, &pid_tgid, &st, BPF_ANY);
    return 0;
}

SEC("uretprobe/SSL_read_ex")
int handle_ssl_read_ex_exit(struct pt_regs *ctx) {
    __u64 pid_tgid = bpf_get_current_pid_tgid();
    struct ssl_read_stash *st = bpf_map_lookup_elem(&ssl_read_args, &pid_tgid);
    if (!st)
        return 0;

    __u64 enter_ts_ns = st->enter_ts_ns;
    __u64 buf_ptr = st->buf_ptr;
    __u64 readbytes_ptr = st->readbytes_ptr;
    bpf_map_delete_elem(&ssl_read_args, &pid_tgid);

    int ret = (int)PT_REGS_RC(ctx);
    if (ret != 1)
        return 0;

    __u64 actual = 0;
    if (bpf_probe_read_user(&actual, sizeof(actual), (const void *)readbytes_ptr) != 0 || actual == 0)
        return 0;

    return emit_ssl_buf(EVENT_SSL_READ, SSL_SUB_READ, (const void *)buf_ptr, actual, enter_ts_ns);
}
