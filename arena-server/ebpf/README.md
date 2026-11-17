# `pit-ebpf-sensor` — Linux Kernel eBPF God's-Eye Telemetry Daemon

Zero-intrusion Linux Kernel eBPF telemetry daemon for **Aexus Colosseum (The Pit)**. Observes live Docker fighter & target containers directly from the host kernel (`Linux 5.15+` with BTF CO-RE + `BPF_MAP_TYPE_RINGBUF`), resolves container `cgroup_id` and IPv4 namespaces in real time, deterministically classifies combat VFX events (`SCHEMA.md` §1.4 & §4), and streams `EBPF_EVENT` records via stdout JSONL, SSE (`/events`), and low-latency HTTP ingest (`--pitd-url`).

## Kernel Probes (`bpf/probes.bpf.c` -> `bpf/probes_bpfel.o`)

- `tracepoint/syscalls/sys_enter_execve` + `tracepoint/syscalls/sys_exit_execve`: Captures `cgroup_id`, `pid`, `ppid`, `uid`, `comm`, `parent_comm`, `filename`, and `argv[0..3]` while filtering failed `-ENOENT` `$PATH` lookups in-kernel.
- `tracepoint/syscalls/sys_enter_connect`: Captures IPv4 & IPv4-mapped IPv6 `connect()` destination IP & port for both outbound exploit beams and target-to-fighter reverse shells.
- `tracepoint/syscalls/sys_enter_openat`: Captures sensitive reads (`/flag`, `/pit/king_beacon`, `/etc/shadow`, `.env`, `id_rsa`) and target source/config writes (`.py`, `.js`, `.ts`, `.php`, `.go`, `.java`, `.conf`, `/app/`, `/var/www/`, `/pit/`).
- `tracepoint/syscalls/sys_enter_setuid`, `tracepoint/syscalls/sys_enter_setresuid`, `kprobe/commit_creds`: Detects non-root -> `uid=0` privilege escalation inside containers.
- `uprobe/SSL_write`, `uprobe/SSL_write_ex`, `uprobe/SSL_read` + `uretprobe/SSL_read`, `uprobe/SSL_read_ex` + `uretprobe/SSL_read_ex`: Dynamically discovers `libssl.so*` across host and `/proc/<container_pid>/root/...` overlays (deduplicated by `(st_dev, st_ino)`) and captures up to 512 bytes of pre-encryption / post-decryption cleartext payload.

## Build & Test

```bash
# Run unit tests + build static Linux x86_64 & host binaries
./build.sh

# Optional: recompile C eBPF program (bpf/probes.bpf.c -> bpf/probes_bpfel.o)
./build.sh --compile-bpf
```

## Runtime Usage

```bash
# Production Linux host (requires root / CAP_BPF + CAP_PERFMON + CAP_SYS_ADMIN)
sudo /srv/arena/ebpf/pit-ebpf-sensor \
  --listen 127.0.0.1:18882 \
  --pitd-url http://127.0.0.1:18880/api/v1/internal/ebpf-ingest

# macOS / non-Linux local development replay mode
./dist/pit-ebpf-sensor --replay-demo --listen 127.0.0.1:18882
```

## HTTP Endpoints (default `127.0.0.1:18882`)

- `GET /status` (alias `GET /health`): Returns `mode` (`kernel_ebpf` | `replay_sim`), `btf_enabled`, `attached_probes`, `ssl_libraries_hooked`, `tracked_containers`, and `events_captured`.
- `GET /events`: Returns recent JSON events (`?limit=100`), or live Server-Sent Events when `Accept: text/event-stream` or `?stream=1` is supplied.
