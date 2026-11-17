#!/usr/bin/env bash
set -euo pipefail

# One-click build & deployment of The Pit (pit-ebpf-sensor + pitd + web-ui)
# to a remote Linux Arena server (default SSH host alias: "arena").

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SSH="${PIT_SSH_TARGET:-arena}"
REMOTE_ROOT="${PIT_REMOTE_ROOT:-/srv/arena}"

echo "==> [1/4] Building Linux x86_64 eBPF God's-Eye Sensor (pit-ebpf-sensor)..."
(
  cd "${ROOT_DIR}/arena-server/ebpf"
  GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" \
    -o dist/pit-ebpf-sensor-linux-amd64 ./cmd/pit-ebpf-sensor
)

echo "==> [2/4] Building Linux x86_64 Arena Core & Forced LLM Gateway (pitd)..."
(
  cd "${ROOT_DIR}/arena-server/pitd"
  GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" \
    -o bin/pitd-linux-amd64 ./cmd/pitd
)

echo "==> [3/4] Building Cross-Platform Esports Broadcast Web UI (web-ui/dist)..."
(
  cd "${ROOT_DIR}/web-ui"
  npm run build
)

echo "==> [4/4] Bootstrapping runtime dependencies, uploading binaries & configuring systemd on ${TARGET_SSH}..."
ssh "${TARGET_SSH}" bash -s -- "${REMOTE_ROOT}" <<'EOF'
set -euo pipefail
REMOTE_ROOT="$1"
ARENA_USER="$(id -un)"
ARENA_GROUP="$(id -gn)"

if ! command -v docker >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io git curl ca-certificates
fi
sudo systemctl enable --now docker
sudo usermod -aG docker "${ARENA_USER}" || true

sudo mkdir -p "${REMOTE_ROOT}/bin" "${REMOTE_ROOT}/ebpf" "${REMOTE_ROOT}/web-ui/dist" "${REMOTE_ROOT}/pit-runtime"
sudo chown -R "${ARENA_USER}:${ARENA_GROUP}" "${REMOTE_ROOT}"
sudo systemctl stop pitd.service pit-ebpf-sensor.service 2>/dev/null || true

sudo tee /etc/systemd/system/pitd.service >/dev/null <<UNIT
[Unit]
Description=Aexus Colosseum (The Pit) Core Control Plane & LLM Metering Gateway
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=${ARENA_USER}
Group=${ARENA_GROUP}
SupplementaryGroups=docker
WorkingDirectory=${REMOTE_ROOT}
Environment="NO_PROXY=localhost,127.0.0.1,::1,host.docker.internal,172.16.0.0/12"
ExecStart=${REMOTE_ROOT}/bin/pitd --addr :18880 --arena-root ${REMOTE_ROOT} --web-dir ${REMOTE_ROOT}/web-ui/dist --work-dir ${REMOTE_ROOT}/pit-runtime
Restart=always
RestartSec=2
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT

sudo tee /etc/systemd/system/pit-ebpf-sensor.service >/dev/null <<UNIT
[Unit]
Description=Aexus Colosseum (The Pit) Linux Kernel eBPF God-Eye Telemetry Sensor
After=network.target docker.service pitd.service

[Service]
Type=simple
User=root
WorkingDirectory=${REMOTE_ROOT}/ebpf
ExecStart=${REMOTE_ROOT}/ebpf/pit-ebpf-sensor --listen 127.0.0.1:18882 --pitd-url http://127.0.0.1:18880/api/v1/internal/ebpf-ingest
Restart=always
RestartSec=2
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
UNIT
EOF

scp "${ROOT_DIR}/arena-server/pitd/bin/pitd-linux-amd64" "${TARGET_SSH}:${REMOTE_ROOT}/bin/pitd"
scp "${ROOT_DIR}/arena-server/ebpf/dist/pit-ebpf-sensor-linux-amd64" "${TARGET_SSH}:${REMOTE_ROOT}/ebpf/pit-ebpf-sensor"
rsync -az --delete "${ROOT_DIR}/web-ui/dist/" "${TARGET_SSH}:${REMOTE_ROOT}/web-ui/dist/"

ssh "${TARGET_SSH}" "chmod +x ${REMOTE_ROOT}/bin/pitd ${REMOTE_ROOT}/ebpf/pit-ebpf-sensor && \
  sudo systemctl daemon-reload && \
  sudo systemctl enable --now pitd.service pit-ebpf-sensor.service && \
  sleep 2 && \
  curl -fsS http://127.0.0.1:18880/api/v1/health"
echo ""
echo "✅ Aexus Colosseum (The Pit) deployed & active on ${TARGET_SSH}!"
