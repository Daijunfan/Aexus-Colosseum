#!/usr/bin/env python3
"""Cache selected upstream training sources without starting any services."""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from datetime import datetime, timezone

SOURCES = [
    ("google-ctf", "Google CTF 历年赛题", "google/google-ctf", "赛事官方", "Web、Pwn、Crypto、逆向与硬件赛题"),
    ("mbe", "RPISEC 二进制利用课程", "RPISEC/MBE", "课程原作者", "二进制实验源码、安装说明与练习资源"),
    ("how2heap", "how2heap 堆利用练习", "shellphish/how2heap", "项目原作者", "按 glibc 版本分类的堆机制与利用样例"),
    ("ctf-challenges", "CTF Wiki 配套题目", "ctf-wiki/ctf-challenges", "社区整理", "配套 Wiki 的分类题目与附件"),
    ("crapi", "OWASP crAPI", "OWASP/crAPI", "项目官方", "API 安全挑战、部署配置与文档"),
    ("dvna", "Damn Vulnerable NodeJS", "appsecco/dvna", "项目原作者", "Node.js Web 安全练习与说明"),
    ("vampi", "VAmPI API 安全靶场", "erev0s/VAmPI", "项目原作者", "REST API 漏洞练习、OpenAPI 描述与测试资料"),
]


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def environment():
    env = {**os.environ, "GIT_TERMINAL_PROMPT": "0"}
    # Reuse Arena's configured egress; never copy credentials into reports.
    if not (env.get("https_proxy") or env.get("HTTPS_PROXY")):
        config = Path("/etc/systemd/system/docker.service.d/proxy.conf")
        if config.is_file():
            urls = re.findall(r'https?://[^\s"\']+', config.read_text())
            if urls:
                env.update(https_proxy=urls[0], http_proxy=urls[0])
    return env


def run(args, env, timeout=1800):
    result = subprocess.run(args, env=env, capture_output=True, timeout=timeout)
    if result.returncode:
        message = result.stderr.decode("utf-8", "replace")[-1000:]
        message = re.sub(r"(https?://)[^/@\s]+:[^/@\s]+@", r"\1[redacted]@", message)
        raise RuntimeError(message)
    return result.stdout


def download(item, root, env):
    source_id, name, repo, authority, description = item
    target = root / "sources" / source_id
    record = dict(id=source_id, name=name, url=f"https://github.com/{repo}",
                  authority=authority, description=description, path=str(target),
                  attackbox_path=f"/shared/library/sources/{source_id}")
    try:
        if not (target / ".git").is_dir():
            temporary = target.with_name(target.name + ".downloading")
            if temporary.exists():
                raise RuntimeError(f"Incomplete checkout exists: {temporary}; inspect before retry")
            run(["git", "clone", "--depth", "1", record["url"] + ".git", str(temporary)], env)
            temporary.rename(target)
        if (target / ".gitmodules").is_file():
            run(["git", "-C", str(target), "submodule", "update", "--init", "--recursive", "--depth", "1"], env)
            record["submodules"] = run(["git", "-C", str(target), "submodule", "status", "--recursive"], env).decode().strip()
        if source_id == "ctf-challenges":
            # Upstream tracks this gitlink but omits .gitmodules. Its exact
            # commit exists in the original challenge author's repository.
            relative = "blockchain/all_challenges/2021/realworld/billboard"
            upstream = "https://github.com/iczc/rwctf-3rd-billboard.git"
            commit = run(["git", "-C", str(target), "rev-parse", "HEAD:" + relative], env).decode().strip()
            child = target / relative
            if not (child / ".git").exists():
                run(["git", "clone", "--depth", "1", "--no-checkout", upstream, str(child)], env)
            run(["git", "-C", str(child), "fetch", "--depth", "1", "origin", commit], env)
            run(["git", "-C", str(child), "checkout", "--detach", commit], env)
            record["supplemental_sources"] = [dict(path=relative, url=upstream, commit=commit)]
        record["commit"] = run(["git", "-C", str(target), "rev-parse", "HEAD"], env).decode().strip()
        tree = run(["git", "-C", str(target), "ls-tree", "-rz", "HEAD"], env)
        record["tree_sha256"] = hashlib.sha256(tree).hexdigest()
        files = [p for p in target.rglob("*") if p.is_file() and ".git" not in p.relative_to(target).parts]
        record["files"] = len(files)
        record["bytes"] = sum(p.stat().st_size for p in files)
        record["readme"] = next((str(p.relative_to(target)) for p in files
                                  if p.parent == target and p.name.lower().startswith("readme")), "")
        record["license_files"] = [str(p.relative_to(target)) for p in files
                                    if p.parent == target and p.name.lower().startswith(("license", "copying"))]
        record["status"] = "downloaded"
        record["downloaded_at"] = now()
    except Exception as error:
        record.update(status="failed", error=str(error))
    return record


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("/srv/arena/shared/library"))
    args = parser.parse_args()
    root = args.root
    (root / "sources").mkdir(parents=True, exist_ok=True)
    manifest = dict(status="running", started_at=now(), collections=[])

    def save():
        temporary = root / "manifest.json.tmp"
        temporary.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        temporary.replace(root / "manifest.json")

    save()
    env = environment()
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(download, item, root, env) for item in SOURCES]
        for future in concurrent.futures.as_completed(futures):
            record = future.result()
            manifest["collections"].append(record)
            save()
            print(record["id"], record["status"], record.get("files", 0), flush=True)
    manifest.update(status="completed", finished_at=now())
    save()
    lines = ["# Arena 离线训练资料", "", "资料按来源保存；下载完成不代表每道题已部署或运行。",
             "在攻击机中使用 `/shared/library/sources`，按各项目 README 准备实验。", ""]
    for record in manifest["collections"]:
        lines += [f"## {record['name']}", f"- 来源：{record['url']}（{record['authority']}）",
                  f"- 状态：{record['status']}", f"- 路径：`{record['attackbox_path']}`",
                  f"- 固定提交：`{record.get('commit', '')}`", ""]
    (root / "README.md").write_text("\n".join(lines))
    return int(any(x["status"] != "downloaded" for x in manifest["collections"]))


if __name__ == "__main__":
    raise SystemExit(main())
