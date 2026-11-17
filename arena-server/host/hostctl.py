#!/usr/bin/env python3
"""Host-side lifecycle controller for the Arena VM (runs on bupt208).

The Mac app never talks to QEMU directly.  It SSHes to bupt208 and runs:

    python3 /home/djf/arena/hostctl.py info
    python3 /home/djf/arena/hostctl.py start
    python3 /home/djf/arena/hostctl.py stop
    python3 /home/djf/arena/hostctl.py tunnel

Every command prints one JSON object.

The reverse SSH tunnel (guest:17890 -> host:17890) gives the guest access to
the server's egress proxy, which Docker and git need for image/source pulls.
It is (re)created automatically after the VM starts.
"""
from __future__ import annotations

import base64
import json
import os
import re
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
VMS = HOME / "vms"
CONFIG = VMS / "manager" / "data" / "vms" / "Arena.json"
PIDFILE = Path("/tmp/arena-proxy-tunnel.pid")
TUNNEL_PORT = 17890
GUEST_KEY = HOME / ".ssh" / "arena_host_ed25519"
VMCTL = VMS / "manager" / "vmctl.py"


def now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def load_config(name: str = "Arena") -> dict:
    try:
        return json.loads((CONFIG.parent / f"{name}.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def vm_running(name: str = "Arena") -> bool:
    pidfile = VMS / "managed" / name / "state" / "qemu.pid"
    try:
        pid = int(pidfile.read_text().strip())
        os.kill(pid, 0)
        cmdline = Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")
        return b"-name" in cmdline and cmdline[cmdline.index(b"-name") + 1].split(b",")[0] == name.encode()
    except (OSError, ValueError):
        return False


def ssh_banner(port: int, timeout: float = 1.2) -> bool:
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=timeout) as sock:
            sock.settimeout(timeout)
            data = sock.recv(64)
            return data.startswith(b"SSH-")
    except OSError:
        return False


def proxy_url() -> str:
    value = os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy") or ""
    if value:
        return value
    for unit in (VMS / "service").glob("*.service"):
        try:
            for line in unit.read_text(encoding="utf-8").splitlines():
                if line.startswith("Environment=HTTPS_PROXY="):
                    return line.split("=", 1)[1]
        except OSError:
            pass
    return ""


def rpc(req: dict, timeout: int = 240) -> dict:
    payload = base64.b64encode(json.dumps(req).encode()).decode()
    proc = subprocess.run([sys.executable, str(VMCTL), "rpc", payload],
                          cwd=str(VMCTL.parent), capture_output=True, text=True,
                          timeout=timeout)
    try:
        return json.loads(proc.stdout.strip().splitlines()[-1])
    except (ValueError, IndexError):
        return {"ok": False, "error": (proc.stderr or proc.stdout).strip()[-500:]}


def find_tunnel_process() -> int | None:
    """Find an already-running tunnel even if it was started outside hostctl."""
    needle = b"-R\x00127.0.0.1:%d:127.0.0.1:%d" % (TUNNEL_PORT, TUNNEL_PORT)
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            cmdline = (entry / "cmdline").read_bytes()
        except OSError:
            continue
        if needle in cmdline and b"arena_host_ed25519" in cmdline:
            pid = int(entry.name)
            PIDFILE.write_text(str(pid))
            return pid
    return None


def tunnel_pid() -> int | None:
    try:
        pid = int(PIDFILE.read_text().strip())
        os.kill(pid, 0)
        return pid
    except (OSError, ValueError):
        return find_tunnel_process()


def guest_listener(ssh_port: int) -> bool:
    try:
        proc = subprocess.run(
            ["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=no",
             "-o", "UserKnownHostsFile=/dev/null", "-p", str(ssh_port),
             "-i", str(GUEST_KEY), "ubuntu@127.0.0.1",
             f"ss -ltn | grep -q ':{TUNNEL_PORT} '"],
            capture_output=True, text=True, timeout=8)
        return proc.returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def tunnel_stop() -> None:
    pid = tunnel_pid()
    if pid:
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass
    PIDFILE.unlink(missing_ok=True)


def tunnel_start(ssh_port: int) -> dict:
    pid = tunnel_pid()
    if pid:
        return {"ok": True, "running": True, "pid": pid, "reused": True}
    if ssh_port and guest_listener(ssh_port):
        return {"ok": True, "running": True, "pid": None, "reused": True,
                "detail": "existing listener found on guest"}
    if not GUEST_KEY.is_file():
        return {"ok": False, "running": False, "error": "guest key missing"}
    log = open("/tmp/arena-proxy-tunnel.log", "ab")
    proc = subprocess.Popen(
        ["ssh", "-N",
         "-o", "ExitOnForwardFailure=yes",
         "-o", "StrictHostKeyChecking=no",
         "-o", "UserKnownHostsFile=/dev/null",
         "-o", "ServerAliveInterval=30",
         "-o", "ServerAliveCountMax=3",
         "-R", f"127.0.0.1:{TUNNEL_PORT}:127.0.0.1:{TUNNEL_PORT}",
         "-p", str(ssh_port), "-i", str(GUEST_KEY), "ubuntu@127.0.0.1"],
        stdout=log, stderr=log, stdin=subprocess.DEVNULL, start_new_session=True)
    PIDFILE.write_text(str(proc.pid))
    time.sleep(1.5)
    if proc.poll() is not None:
        PIDFILE.unlink(missing_ok=True)
        return {"ok": False, "running": False, "error": "tunnel exited; see /tmp/arena-proxy-tunnel.log"}
    return {"ok": True, "running": True, "pid": proc.pid, "reused": False}


def info(name: str = "Arena") -> dict:
    cfg = load_config(name)
    running = vm_running(name)
    port = int(cfg.get("ssh_port") or 0)
    ready = running and port > 0 and ssh_banner(port)
    return {
        "ok": True,
        "name": name,
        "exists": bool(cfg),
        "running": running,
        "ready": ready,
        "cpu": cfg.get("cpu"),
        "ram_gb": cfg.get("ram_gb"),
        "disk_gb": cfg.get("disk_gb"),
        "extra_disks": cfg.get("extra_disks", []),
        "ssh_port": port,
        "tunnel": ({"running": tunnel_pid() is not None, "port": TUNNEL_PORT}
                   if name == "Arena" else None),
        "time": now(),
    }


def start(name: str = "Arena") -> dict:
    cfg = load_config(name)
    if not cfg:
        return {"ok": False, "error": f"{name} VM not found"}
    if not vm_running(name):
        result = rpc({"op": "vm_start", "name": name}, timeout=300)
        if not result.get("ok"):
            return result
    port = int(cfg.get("ssh_port") or 0)
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        if ssh_banner(port):
            break
        time.sleep(2)
    else:
        return {"ok": False, "error": "guest SSH did not become ready in time", **info(name)}
    out = info(name)
    if name == "Arena":
        out["tunnel_result"] = tunnel_start(port)
        out["proxy_configured"] = bool(proxy_url())
    return out


def stop(name: str = "Arena") -> dict:
    if name == "Arena":
        tunnel_stop()
    if vm_running(name):
        result = rpc({"op": "vm_stop", "name": name}, timeout=300)
        if not result.get("ok"):
            return result
    return info(name)


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else "info"
    name = "Arena-Kali" if command.startswith("kali-") else "Arena"
    command = command.removeprefix("kali-")
    try:
        if command == "info":
            out = info(name)
        elif command == "start":
            out = start(name)
        elif command == "stop":
            out = stop(name)
        elif command == "tunnel":
            cfg = load_config()
            out = tunnel_start(int(cfg.get("ssh_port") or 0))
        else:
            out = {"ok": False, "error": f"unknown command: {command}"}
    except subprocess.TimeoutExpired:
        out = {"ok": False, "error": "operation timed out"}
    except OSError as exc:
        out = {"ok": False, "error": str(exc)}
    print(json.dumps(out, ensure_ascii=False))
    return 0 if out.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
