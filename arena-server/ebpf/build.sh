#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPILE_BPF=0
ARENA_HOST="${ARENA_HOST:-arena}"
BPF_DOCKER_IMAGE="${BPF_DOCKER_IMAGE:-arena-attackbox-attackbox:latest}"

for arg in "$@"; do
  case "$arg" in
    --compile-bpf)
      COMPILE_BPF=1
      ;;
  esac
done

if [[ "$COMPILE_BPF" -eq 1 ]]; then
  echo "[build.sh] Compiling bpf/probes.bpf.c -> bpf/probes_bpfel.o ..."
  if command -v clang >/dev/null 2>&1 && [[ "$(uname -s)" == "Linux" ]]; then
    clang -target bpf -mcpu=v3 -I/usr/include/x86_64-linux-gnu -O2 -g -Wall -Werror \
      -c bpf/probes.bpf.c -o bpf/probes_bpfel.o
  else
    ssh "$ARENA_HOST" 'sudo mkdir -p /srv/arena/ebpf/bpf && sudo chown -R $(id -u):$(id -g) /srv/arena/ebpf'
    scp bpf/bpf_minimal.h bpf/probes.bpf.c "${ARENA_HOST}:/srv/arena/ebpf/bpf/"
    ssh "$ARENA_HOST" "docker run --rm -v /srv/arena/ebpf/bpf:/src -w /src ${BPF_DOCKER_IMAGE} \
      clang -target bpf -mcpu=v3 -I/usr/include/x86_64-linux-gnu -O2 -g -Wall -Werror -c probes.bpf.c -o probes_bpfel.o"
    scp "${ARENA_HOST}:/srv/arena/ebpf/bpf/probes_bpfel.o" bpf/probes_bpfel.o
  fi
fi

mkdir -p dist

echo "[build.sh] Running unit tests ..."
go test -count=1 ./...

echo "[build.sh] Cross-compiling static Linux x86_64 binary -> dist/pit-ebpf-sensor-linux-amd64 ..."
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" \
  -o dist/pit-ebpf-sensor-linux-amd64 ./cmd/pit-ebpf-sensor

echo "[build.sh] Compiling host binary -> dist/pit-ebpf-sensor ..."
CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" \
  -o dist/pit-ebpf-sensor ./cmd/pit-ebpf-sensor

ls -lh bpf/probes_bpfel.o dist/pit-ebpf-sensor-linux-amd64 dist/pit-ebpf-sensor
