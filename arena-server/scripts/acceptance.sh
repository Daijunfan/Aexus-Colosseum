#!/bin/zsh
# Real-server acceptance test for the AWD arena.
#
#   ./scripts/acceptance.sh               # deploy, then run the test
#   ./scripts/acceptance.sh --skip-deploy # test the already deployed server
#   ./scripts/acceptance.sh --teams=1,2   # override which teams get started
#
# Creates a 5-team arena (1 service + 1 attacker per team), starts two teams,
# runs the real HTTP + attacker-reachability verification, then stops them
# again and proves the verdict survived.  The event is intentionally left in
# the registry so the Mac app can display it; no containers stay running.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH_OPTS=(-J bupt208 -p 22004 -i "$HOME/.ssh/id_ed25519_arena"
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
  -o ConnectTimeout=10)
ARENA=(ssh "${SSH_OPTS[@]}" ubuntu@127.0.0.1)
TEAMS="t1,t2"
SKIP_DEPLOY=0
for arg in "$@"; do
  case "$arg" in
    --skip-deploy) SKIP_DEPLOY=1 ;;
    --teams=*) TEAMS="${arg#--teams=}" ;;
    t[0-9],*|t[0-9]) TEAMS="$arg" ;;
  esac
done
# Support `--teams 1,2` as well as `--teams=t1,t2`.
TEAMS="${TEAMS//[!0-9,]/}"
[[ "$TEAMS" == ,* ]] && TEAMS="${TEAMS#,}"
[[ "$TEAMS" == *, ]] && TEAMS="${TEAMS%,}"
TEAMS="$(echo "$TEAMS" | sed -E 's/([0-9]+)/t\1/g')"

echo "▸ Checking Arena connectivity…"
if ! "${ARENA[@]}" 'echo ok' >/dev/null 2>&1; then
  echo "✗ Cannot reach Arena. Connect to the campus network first." >&2
  exit 2
fi

if [[ "$SKIP_DEPLOY" -eq 0 ]]; then
  echo "▸ Deploying current server code…"
  "$ROOT/scripts/deploy.sh"
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
NAME="验收竞技场 $STAMP"

echo "▸ Creating 5-team arena…"
CREATED="$("${ARENA[@]}" "arenactl awd create '{\"name\":\"$NAME\",\"teams\":5,\"services\":1,\"attackers\":1}'")"
EVENT="$(echo "$CREATED" | python3 -c 'import sys,json;print(json.load(sys.stdin)["event"]["id"])')"
echo "  event: $EVENT"

echo "▸ Starting teams $TEAMS (nothing else)…"
"${ARENA[@]}" "arenactl awd start $EVENT --teams $TEAMS" > /tmp/arena-accept-start.json
python3 - /tmp/arena-accept-start.json "$TEAMS" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
want={f"t{x}" for x in sys.argv[2].split(",")}
started={a.get("team") for a in d.get("started") or []}
assert started==want, (started,want,d.get("errors"))
assert d.get("ok"), d
print(f"  ✓ started {len(d['started'])} containers: {', '.join(sorted(started))}")
PY

echo "▸ Verifying teams $TEAMS against the real services…"
"${ARENA[@]}" "arenactl awd verify $EVENT --teams $TEAMS" > /tmp/arena-accept-verify.json
python3 - /tmp/arena-accept-verify.json <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
assert d.get("ok"), d
for r in d["results"]:
    assert r["ok"] and not r.get("untested"), r
    print(f"  ✓ {r['team_id']}: {r.get('detail') or 'ok'}")
PY

echo "▸ Stopping teams $TEAMS…"
"${ARENA[@]}" "arenactl awd stop $EVENT --teams $TEAMS" > /tmp/arena-accept-stop.json
python3 - /tmp/arena-accept-stop.json <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
assert d.get("ok"), d
print(f"  ✓ stopped {len(d.get('stopped') or [])} containers")
PY

echo "▸ Confirming verdict survives the stop and no container is left running…"
STATUS="$("${ARENA[@]}" "arenactl awd status $EVENT")"
echo "$STATUS" | python3 -c '
import sys,json
d=json.load(sys.stdin)
assert d["ok"], d
verified=[t["id"] for t in d["teams"] if t["verified"]]
running=[t["id"] for t in d["teams"] if t["running"]]
assert verified, "verification was lost after stop"
assert not running, f"teams still running: {running}"
print(f"  ✓ verified after stop: {', '.join(verified)}")
print(f"  ✓ running teams: {len(running)}")
'
LEFT="$("${ARENA[@]}" "docker ps --format '{{.Names}}' | grep '^Arena-awd-' || true")"
if [[ -n "$LEFT" ]]; then
  echo "✗ AWD containers still running:" >&2
  echo "$LEFT" >&2
  exit 1
fi

echo
echo "✓ AWD acceptance passed. Event '$EVENT' is visible in the app as verified."
echo "  Open 攻防赛事 → select this event → teams $TEAMS show 已验证."
echo "  Start them again from the app when you are ready to play."
