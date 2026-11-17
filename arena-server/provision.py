#!/usr/bin/env python3
"""Materialise the Aexus Colosseum catalog on the Arena server.

Run on Arena:

    python3 provision.py --root /srv/arena

It
  1. copies the selected Vulhub directories into catalog/labs/<id>/
  2. writes a lab.json for every Vulhub entry (ports parsed from compose)
  3. generates catalog/catalog.json, the index the app and arenactl read

Curated labs are already complete on disk (lab.json + compose + build files);
they are only indexed here.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
from pathlib import Path

WEB_PORTS = {80, 443, 3000, 4000, 5000, 5001, 7001, 8000, 8001, 8010, 8080,
             8081, 8082, 8083, 8084, 8085, 8086, 8087, 8088, 8090, 8443, 8888,
             8983, 9090, 10000}
PORT_LABELS = {
    80: "HTTP", 443: "HTTPS", 3000: "Web", 4000: "Web", 5000: "Web",
    5001: "Web", 6379: "Redis", 7001: "WebLogic", 8080: "Web", 8081: "Web",
    8082: "Web", 8083: "Web", 8084: "Web", 8085: "Web", 8086: "Web",
    8087: "Web", 8088: "Web", 8090: "Web", 8888: "UI", 8983: "Solr",
    3306: "MySQL", 5432: "PostgreSQL", 22: "SSH", 21: "FTP", 102: "S7",
    502: "Modbus", 27017: "MongoDB",
}


def load_compose(path: Path):
    try:
        import yaml
    except ImportError:  # pragma: no cover - provisioned by the bootstrap
        raise SystemExit("PyYAML is required: apt-get install -y python3-yaml")
    with path.open(encoding="utf-8") as fh:
        return yaml.safe_load(fh) or {}


def published_ports(compose: dict) -> list[tuple[int, int]]:
    """Return (host_port, container_port) pairs from a compose document."""
    result: list[tuple[int, int]] = []
    services = compose.get("services") or {}
    for svc in services.values():
        if not isinstance(svc, dict):
            continue
        for item in svc.get("ports") or []:
            if isinstance(item, int):
                result.append((item, item))
                continue
            if not isinstance(item, str):
                continue
            spec = item.split("/")[0]
            bits = spec.split(":")
            if len(bits) == 1:
                try:
                    p = int(bits[0])
                except ValueError:
                    continue
                result.append((p, p))
            else:
                try:
                    host = int(bits[-2])
                    guest = int(bits[-1])
                except ValueError:
                    continue
                result.append((host, guest))
    # unique, stable ordering
    out = []
    seen = set()
    for pair in result:
        if pair not in seen:
            seen.add(pair)
            out.append(pair)
    return out


def access_for(pairs: list[tuple[int, int]], web_hints: dict | None = None) -> list[dict]:
    access = []
    web_hints = web_hints or {}
    for host, guest in pairs[:4]:
        if guest in WEB_PORTS or host in web_hints:
            scheme = web_hints.get(host) or ("https" if guest == 443 else "http")
            access.append({"label": PORT_LABELS.get(guest, f"端口 {guest}"),
                           "port": host, "scheme": scheme, "path": "/"})
        else:
            access.append({"label": PORT_LABELS.get(guest, f"端口 {guest}"),
                           "port": host, "scheme": "tcp", "path": ""})
    return access


def find_compose(directory: Path) -> Path | None:
    for name in ("docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml"):
        candidate = directory / name
        if candidate.is_file():
            return candidate
    return None


def materialise_vulhub(root: Path, spec: dict) -> list[dict]:
    source_root = root / "catalog" / "sources" / "vulhub"
    if not source_root.is_dir():
        # A fresh server may be provisioned before the Vulhub checkout is
        # seeded; curated labs still work, so index them and say so loudly
        # instead of leaving the whole catalog unusable.
        print(f"WARN  Vulhub source missing: {source_root} — "
              f"skipping {len(spec.get('vulhub', []))} Vulhub labs")
        return []
    labs = []
    for item in spec.get("vulhub", []):
        src = source_root / item["path"]
        if not src.is_dir():
            print(f"WARN  missing Vulhub path: {item['path']}")
            continue
        target = root / "catalog" / "labs" / item["id"]
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(src, target, symlinks=True)
        compose_path = find_compose(target)
        if compose_path is None:
            print(f"WARN  no compose file in {item['path']}")
            continue
        compose = load_compose(compose_path)
        ports = published_ports(compose)
        documentation = "\n".join(p.read_text(encoding="utf-8", errors="replace")
                                  for p in target.glob("README*.md"))
        web_hints = {int(port or (443 if scheme == "https" else 80)): scheme
                     for scheme, port in re.findall(
                         r"(https?)://(?:your-ip|yourip|localhost|127\.0\.0\.1)(?::(\d+))?",
                         documentation, re.I)}
        access = item.get("access") or access_for(ports, web_hints)
        meta = {
            "id": item["id"],
            "name": item["name"],
            "subtitle": item.get("subtitle", ""),
            "category": item.get("category", "cve"),
            "source": "vulhub",
            "source_path": item["path"],
            "source_url": "https://github.com/vulhub/vulhub",
            "difficulty": item.get("difficulty", 3),
            "tags": item.get("tags", []),
            "summary": item.get("summary", ""),
            "objectives": item.get("objectives", []),
            "mitre": item.get("mitre", []),
            "ram_mb": item.get("ram_mb", 3072),
            "cpu": float(item.get("cpu", 2.5)),
            "access": access,
            "credentials": item.get("credentials", ""),
            "notes": item.get("notes", ""),
            "compose": compose_path.name,
            "build": any(isinstance(service, dict) and service.get("build")
                         for service in (compose.get("services") or {}).values()),
            "ports": [{"host": h, "container": g} for h, g in ports],
        }
        (target / "lab.json").write_text(
            json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        labs.append(meta)
    return labs


def index(root: Path, categories: list[dict]) -> dict:
    labs = []
    for lab_dir in sorted((root / "catalog" / "labs").iterdir()):
        meta_path = lab_dir / "lab.json"
        if not meta_path.is_file():
            continue
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            print(f"WARN  cannot read {meta_path}: {exc}")
            continue
        meta.setdefault("id", lab_dir.name)
        meta.setdefault("category", "misc")
        meta.setdefault("access", [])
        meta.setdefault("tags", [])
        meta.setdefault("objectives", [])
        meta.setdefault("mitre", [])
        meta["compose"] = meta.get("compose") or "docker-compose.yml"
        labs.append(meta)
    catalog = {
        "version": 1,
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "categories": categories,
        "labs": labs,
    }
    (root / "catalog" / "catalog.json").write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return catalog


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="/srv/arena")
    args = parser.parse_args()
    root = Path(args.root)
    spec_path = root / "catalog" / "vulhub-spec.json"
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    vulhub_labs = materialise_vulhub(root, spec)
    catalog = index(root, spec["categories"])
    curated = [lab for lab in catalog["labs"] if lab.get("source") != "vulhub"]
    print(f"indexed {len(catalog['labs'])} labs "
          f"({len(curated)} curated, {len(vulhub_labs)} vulhub)")


if __name__ == "__main__":
    main()
