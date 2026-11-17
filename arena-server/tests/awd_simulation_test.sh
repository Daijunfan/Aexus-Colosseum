#!/usr/bin/env bash
# Offline regression for Arena's AWD orchestration.
#
# Replaces docker/curl with recording shims so the full create → start →
# verify → stop → verify → remove lifecycle can be exercised without a
# Docker host.  It checks the constraints the product promises:
#   * every machine is named Arena-awd-*
#   * create starts nothing
#   * start/stop/verify are team-scoped
#   * stopping preserves the previous verification
#   * deleting an event removes its hosts and containers
#   * two events never share a published port
#
#   ./tests/awd_simulation_test.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/arena-awd-sim.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin" "$WORK/state" "$WORK/root/platform"
cp -R "$ROOT/catalog" "$WORK/root/" 2>/dev/null || true

# --- docker shim -----------------------------------------------------------
# State is one file per running container in $ARENA_TEST_STATE.
cat > "$WORK/bin/docker" <<'SHIM'
#!/usr/bin/env bash
state="$ARENA_TEST_STATE"
cmd="$1"
case "$cmd" in
  image) exit 0 ;;
  run)
    name=""; prev=""
    for a in "$@"; do [ "$prev" = "--name" ] && name="$a"; prev="$a"; done
    [ -n "$name" ] || { echo "shim: run without --name" >&2; exit 2; }
    touch "$state/$name"
    echo "shim-container-$name"; exit 0 ;;
  inspect)
    name="${*: -1}"
    [ -f "$state/$name" ] && { echo running; exit 0; }
    echo "no such container" >&2; exit 1 ;;
  start) touch "$state/$2"; exit 0 ;;
  stop) rm -f "$state/$4"; exit 0 ;;
  rm)
    for a in "$@"; do rm -f "$state/$a"; done; exit 0 ;;
  exec) echo 200; exit 0 ;;
  ps|stats) exit 0 ;;
  *) exit 0 ;;
esac
SHIM
cat > "$WORK/bin/curl" <<'SHIM'
#!/usr/bin/env bash
echo 200
SHIM
chmod +x "$WORK/bin/docker" "$WORK/bin/curl"

export PATH="$WORK/bin:$PATH"
export ARENA_ROOT="$WORK/root"
export ARENA_TEST_STATE="$WORK/state"
CTL=(python3 "$ROOT/bin/arenactl")

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ✓ $*"; }

jsonget() { python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }

# Optional: copy the real CLI payloads for the Swift contract tests.
CAPTURE="${ARENA_CAPTURE:-}"
capture() { [ -n "$CAPTURE" ] && { mkdir -p "$CAPTURE"; cat > "$CAPTURE/$1"; } || true; }

echo "▸ create: 5 teams × 2 services × 2 attackers"
CREATED="$("${CTL[@]}" awd create '{"name":"模拟竞技场","teams":5,"services":2,"attackers":2}')"
capture awd_create.json <<<"$CREATED"
EVENT="$(echo "$CREATED" | jsonget 'd["event"]["id"]')"
[ "$(echo "$CREATED" | jsonget 'd["count"]')" = "20" ] || fail "expected 20 hosts"
[ "$(echo "$CREATED" | jsonget 'd["event"]["status"]')" = "draft" ] || fail "create must not start the event"
[ "$(echo "$CREATED" | jsonget 'len(d["hosts"])')" = "20" ] || fail "host records missing"
echo "$CREATED" | python3 -c '
import json,sys
d=json.load(sys.stdin)
bad=[h["id"] for h in d["hosts"] if not h["docker"]["container"].startswith("Arena-awd-")]
assert not bad, bad
names={h["name"] for h in d["hosts"]}
assert all(n.startswith("Arena 队 ") for n in names), names
assert sum("服务机" in n for n in names)==10 and sum("攻击机" in n for n in names)==10, names
ports=[p for h in d["hosts"] for p in h["ports"]]
assert len(ports)==len(set(ports))==10, ports
' || fail "naming or port constraints"
[ -z "$(ls -A "$WORK/state")" ] || fail "create started containers"
pass "20 Arena machines registered, nothing started"
"${CTL[@]}" events list > "$WORK/events.json"
capture events.json < "$WORK/events.json"
"${CTL[@]}" events invite "$EVENT" > "$WORK/invite.json" 2>/dev/null || true
[ -s "$WORK/invite.json" ] && capture invite.json < "$WORK/invite.json"

echo "▸ start only team 1"
"${CTL[@]}" awd start "$EVENT" --teams t1 > "$WORK/start.json"
capture awd_start.json < "$WORK/start.json"
[ "$(ls "$WORK/state" | wc -l | tr -d ' ')" = "4" ] || fail "expected 4 containers running for t1"
[ "$(ls "$WORK/state" | grep -c '^Arena-awd-.*-t1-')" = "4" ] || fail "someone outside t1 started"
pass "exactly 4 t1 containers running"

echo "▸ verify started and stopped teams"
"${CTL[@]}" awd verify "$EVENT" --teams t1,t2 > "$WORK/v1.json"
capture awd_verify.json < "$WORK/v1.json"
"${CTL[@]}" awd status "$EVENT" > "$WORK/status.json"
capture awd_status.json < "$WORK/status.json"
python3 - "$WORK/v1.json" <<'PY' || fail "verify result wrong"
import json,sys
d=json.load(open(sys.argv[1]))
r={x["team_id"]:x for x in d["results"]}
assert r["t1"]["ok"] is True and not r["t1"].get("untested"), r["t1"]
assert r["t2"]["ok"] is False and r["t2"].get("untested") is True, r["t2"]
PY
pass "t1 passes real HTTP + attacker reach; t2 is untested"

echo "▸ stop team 1, keep its verdict"
"${CTL[@]}" awd stop "$EVENT" --teams t1 > "$WORK/stop.json"
capture awd_stop.json < "$WORK/stop.json"
[ -z "$(ls -A "$WORK/state")" ] || fail "stop left containers running"
"${CTL[@]}" awd verify "$EVENT" --teams t1 > "$WORK/v2.json"
python3 - "$WORK/v2.json" <<'PY' || fail "stopped verification must be untested"
import json,sys
r=json.load(open(sys.argv[1]))["results"][0]
assert r.get("untested") is True and r["ok"] is False, r
PY
STATUS="$("${CTL[@]}" awd status "$EVENT")"
[ "$(echo "$STATUS" | jsonget 'sum(1 for t in d["teams"] if t["verified"])')" = "1" ] || fail "verified verdict lost after stop"
[ "$(echo "$STATUS" | jsonget 'sum(1 for t in d["teams"] if t["running"])')" = "0" ] || fail "status says still running"
pass "verdict preserved, nothing running"

echo "▸ second event gets distinct ports"
SECOND="$("${CTL[@]}" awd create '{"name":"第二竞技场","teams":1,"services":1,"attackers":1}')"
SECOND_ID="$(echo "$SECOND" | jsonget 'd["event"]["id"]')"
python3 - "$WORK" "$SECOND_ID" <<'PY' || fail "port collision between events"
import json,sys,pathlib
work=pathlib.Path(sys.argv[1])
hosts=json.load(open(work/"root/platform/hosts.json"))["hosts"]
ports=[p for h in hosts for p in h.get("ports") or []]
assert len(ports)==len(set(ports)), ports
PY
pass "port ranges do not overlap"

echo "▸ remove cleans containers and hosts"
"${CTL[@]}" awd start "$EVENT" --teams t2 >/dev/null
"${CTL[@]}" events remove "$EVENT" >/dev/null
[ -z "$(ls -A "$WORK/state" | grep 'Arena-awd' || true)" ] || fail "containers left after remove"
python3 - "$WORK" "$EVENT" <<'PY' || fail "host records left after remove"
import json,sys,pathlib
hosts=json.load(open(pathlib.Path(sys.argv[1])/"root/platform/hosts.json"))["hosts"]
left=[h["id"] for h in hosts if h["id"].startswith("awd-") and sys.argv[2].split("-")[1] in h["id"]]
assert not left, left
PY
pass "event removal dropped its containers and records"

echo "▸ AWD lifecycle simulation passed"
