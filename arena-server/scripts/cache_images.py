#!/usr/bin/env python3
"""Cache selected lab images, deduplicating shared layers without starting labs."""
import argparse
import concurrent.futures
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("/srv/arena"))
    parser.add_argument("--ids-file", type=Path, required=True)
    args = parser.parse_args()
    ids = json.loads(args.ids_file.read_text())
    report_dir = args.root / "shared/library"
    logs = report_dir / "image-logs"
    logs.mkdir(parents=True, exist_ok=True)
    report = dict(status="running", started_at=now(), labs=[], images=[])

    def save():
        path = report_dir / "image-cache.json"
        temporary = path.with_suffix(".tmp")
        temporary.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        temporary.replace(path)

    def inspect(image):
        result = subprocess.run(["docker", "image", "inspect", image], capture_output=True, text=True, timeout=30)
        if result.returncode: return None
        item = json.loads(result.stdout)[0]
        return dict(image_id=item["Id"], bytes=item["Size"], digests=item.get("RepoDigests", []))

    def pull(image):
        log = logs / (hashlib.sha256(image.encode()).hexdigest()[:16] + ".log")
        record = dict(name=image, log=str(log))
        try:
            before = inspect(image)
            if before:
                return {**record, **before, "status": "cached", "reused": True}
            with log.open("w") as output:
                result = subprocess.run(["docker", "pull", image], stdout=output, stderr=subprocess.STDOUT, timeout=1800)
            after = inspect(image)
            if result.returncode or not after:
                raise RuntimeError(log.read_text(errors="replace")[-600:])
            return {**record, **after, "status": "cached", "reused": False}
        except Exception as error:
            return {**record, "status": "failed", "error": str(error)}

    images = set()
    builds = []
    save()
    for lab_id in ids:
        row = dict(id=lab_id, status="preparing", images=[])
        try:
            result = subprocess.run([str(args.root / "bin/arenactl"), "install", lab_id, "--no-pull"],
                                    capture_output=True, text=True, timeout=120)
            response = json.loads(result.stdout)
            if not response.get("ok"): raise RuntimeError(response.get("error", "materialisation failed"))
            directory = args.root / "labs" / lab_id
            meta = json.loads((directory / "lab.json").read_text())
            command = ["docker", "compose", "-p", "arena-" + lab_id, "-f", str(directory / meta.get("compose", "docker-compose.yml"))]
            override = directory / "docker-compose.override.yml"
            if override.is_file(): command += ["-f", str(override)]
            result = subprocess.run(command + ["config", "--images"], cwd=directory,
                                    capture_output=True, text=True, timeout=45)
            if result.returncode: raise RuntimeError(result.stderr[-600:])
            row["images"] = sorted(set(result.stdout.splitlines()))
            if not row["images"]: raise RuntimeError("No images declared; requires a separate build")
            config = subprocess.run(command + ["config", "--format", "json"], cwd=directory,
                                    capture_output=True, text=True, check=True, timeout=45)
            services = json.loads(config.stdout)["services"]
            built = {service.get("image") or f"arena-{lab_id}-{name}" for name, service in services.items()
                     if service.get("build")}
            images.update(set(row["images"]) - built)
            if built: builds.append((lab_id, directory, command, built))
            row["status"] = "waiting"
        except Exception as error:
            row.update(status="failed", error=str(error))
        report["labs"].append(row)
        save()
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(pull, image) for image in sorted(images)]
        for future in concurrent.futures.as_completed(futures):
            record = future.result()
            report["images"].append(record)
            save()
            print(record["status"], record["name"], flush=True)
    for lab_id, directory, command, built in builds:
        missing = [image for image in built if not inspect(image)]
        log = logs / (lab_id + "-build.log")
        if missing:
            try:
                with log.open("w") as output:
                    subprocess.run(command + ["build"], cwd=directory, stdout=output,
                                   stderr=subprocess.STDOUT, timeout=1800)
            except subprocess.TimeoutExpired:
                pass
        for image in sorted(built):
            details = inspect(image)
            record = dict(name=image, log=str(log), built=True)
            if details:
                record.update(**details, status="cached")
            else:
                record.update(status="failed", error=log.read_text(errors="replace")[-600:] if log.exists() else "build failed")
            report["images"].append(record)
            save()
            print(record["status"], image, flush=True)
    cached = {r["name"] for r in report["images"] if r["status"] == "cached"}
    for lab in report["labs"]:
        if lab["status"] != "failed":
            lab["status"] = "cached" if set(lab["images"]) <= cached else "incomplete"
    report.update(status="completed", finished_at=now())
    save()
    return int(any(lab["status"] != "cached" for lab in report["labs"]))


if __name__ == "__main__":
    raise SystemExit(main())
