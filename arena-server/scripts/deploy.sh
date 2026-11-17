#!/bin/zsh
# Deploy the Arena catalog + control agent from this Mac to the Arena VM.
#
#   ./scripts/deploy.sh            # sync files, install agent, rebuild catalog index
#   ./scripts/deploy.sh --with-host # also install hostctl.py on bupt208
#
# Requires: ssh alias `bupt208`, key ~/.ssh/id_ed25519_arena, rsync.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARENA_SSH=(ssh -J bupt208 -p 22004 -i "$HOME/.ssh/id_ed25519_arena"
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@127.0.0.1)
RSYNC_RSH="ssh -J bupt208 -p 22004 -i $HOME/.ssh/id_ed25519_arena -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

echo "▸ Building catalog locally…"
python3 "$ROOT/build_catalog.py" >/dev/null

echo "▸ Syncing catalog and agent to Arena…"
"${ARENA_SSH[@]}" 'mkdir -p /srv/arena/{catalog,bin,labs,shared,logs}'
# Keep what only exists on the server: the Vulhub checkout, the generated
# index and the materialised Vulhub labs.  Everything else is mirrored.
rsync -az --delete -e "$RSYNC_RSH" \
  --exclude 'sources/' \
  --exclude 'catalog.json' \
  --exclude 'labs/vulhub-*' \
  "$ROOT/catalog/" "ubuntu@127.0.0.1:/srv/arena/catalog/"
rsync -az -e "$RSYNC_RSH" \
  "$ROOT/bin/arenactl" "ubuntu@127.0.0.1:/srv/arena/bin/arenactl"
rsync -az -e "$RSYNC_RSH" \
  "$ROOT/bin/arena-agent" "ubuntu@127.0.0.1:/srv/arena/bin/arena-agent"
rsync -az -e "$RSYNC_RSH" \
  "$ROOT/provision.py" "ubuntu@127.0.0.1:/srv/arena/provision.py"
rsync -az -e "$RSYNC_RSH" \
  "$ROOT/shared/" "ubuntu@127.0.0.1:/srv/arena/shared/"

echo "▸ Installing binaries, indexing the catalog and preparing AWD images…"
"${ARENA_SSH[@]}" 'set -euo pipefail
  command -v docker >/dev/null || { echo "docker is not installed" >&2; exit 1; }
  docker info >/dev/null 2>&1 || { echo "ubuntu cannot talk to the Docker daemon (docker group?)" >&2; exit 1; }
  docker compose version >/dev/null || { echo "docker compose plugin is missing" >&2; exit 1; }
  sudo -n true || { echo "passwordless sudo is required" >&2; exit 1; }
  sudo apt-get install -y -qq python3-yaml curl >/dev/null 2>&1 || true
  sudo install -m 0755 /srv/arena/bin/arenactl /usr/local/bin/arenactl
  sudo install -m 0755 /srv/arena/bin/arena-agent /usr/local/bin/arena-agent
  python3 /srv/arena/provision.py --root /srv/arena
  # AWD needs both images present before an arena can be created.
  docker image inspect vulnerables/web-dvwa:latest >/dev/null 2>&1 \
    || docker pull vulnerables/web-dvwa:latest
  docker compose -p arena-attackbox \
    -f /srv/arena/shared/attackbox/docker-compose.yml build
  docker image inspect vulnerables/web-dvwa:latest >/dev/null
  docker image inspect arena-attackbox-attackbox:latest >/dev/null
  echo "images ready: dvwa + attackbox"'

if [[ "${1:-}" == "--with-host" ]]; then
  echo "▸ Installing host controller on bupt208…"
  ssh bupt208 'mkdir -p ~/arena'
  scp -q "$ROOT/host/hostctl.py" bupt208:~/arena/hostctl.py
fi

echo "▸ Done."
"${ARENA_SSH[@]}" 'arenactl info | python3 -m json.tool | head -30'
