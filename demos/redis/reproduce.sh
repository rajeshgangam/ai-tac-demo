#!/usr/bin/env bash
# Redis CVE-2023-25155 — reproduce the crash and capture the poison value on
# the LIVE server with fr trace. No restart, no printf, no rebuild-to-observe.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"

REDIS="$HERE/redis"
PORT="${PORT:-7890}"
BUGGY_PARENT="b1939b052~1"   # parent of the real CVE fix commit = bug is live

# 1. get redis at the buggy commit + build with symbols
if [ ! -d "$REDIS/.git" ]; then
  echo "== cloning redis =="; git clone --quiet https://github.com/redis/redis.git "$REDIS"
fi
cd "$REDIS"
git checkout -q "$BUGGY_PARENT"
echo "== building redis (-O0 -g, libc malloc) =="
make -j"$(nproc)" MALLOC=libc OPTIMIZATION="-O0" REDIS_CFLAGS="-g3 -fno-omit-frame-pointer -Wno-error" >/tmp/redis_build.log 2>&1
SRV="$REDIS/src/redis-server"; CLI="$REDIS/src/redis-cli"

PID=""
start() {
  "$SRV" --port "$PORT" --daemonize yes --logfile /tmp/redis_$PORT.log --save "" >/dev/null 2>&1
  sleep 1
  PID=$("$CLI" -p "$PORT" info server | awk -F: '/process_id/{gsub(/\r/,"");print $2}')
  "$CLI" -p "$PORT" sadd myset a b c d e >/dev/null
}

echo; echo "############ 1. REPRODUCE THE CRASH ############"
start; echo "server pid=$PID"
echo "\$ redis-cli SRANDMEMBER myset -9223372036854775808"
"$CLI" -p "$PORT" SRANDMEMBER myset -9223372036854775808 2>&1 || true
sleep 1
if kill -0 "$PID" 2>/dev/null; then echo "server: ALIVE"; else echo "server: DEAD (crashed) — one command killed it"; fi
grep -m1 "ASSERTION FAILED" /tmp/redis_$PORT.log || true
grep -m1 "srandmemberWithCountCommand" /tmp/redis_$PORT.log || true

echo; echo "############ 2. CAPTURE THE POISON VALUE ON THE LIVE SERVER ############"
start; echo "fresh server pid=$PID"
SPEC="$HERE/srandmember.bin"   # ABSOLUTE path — the target opens it against ITS OWN cwd
tpc_compile "$HERE/srandmember.tpc" "$SRV" -o "$SPEC" | tail -1
FR_PROBE_LIB="$FR_PROBE_LIB" "$FR" trace attach "$PID" --spec "$SPEC" --tempcode --ttl-sec 300 --max-hz 20000 2>&1 | tail -2

echo "-- benign: SRANDMEMBER myset -3 --"
"$CLI" -p "$PORT" SRANDMEMBER myset -3 >/dev/null; sleep 1
"$FR" trace collect "$PID" --out "$HERE/hits_benign.jsonl" 2>&1 | tail -1 || true
echo "captured: $(cat "$HERE/hits_benign.jsonl" 2>/dev/null)"

echo "-- poison: SRANDMEMBER myset -9223372036854775808 (server will die) --"
"$CLI" -p "$PORT" SRANDMEMBER myset -9223372036854775808 2>&1 || true; sleep 1
# the ring persists in /dev/shm after the crash
"$FR" trace collect "/dev/shm/fr_probe.$PID.ring" --out "$HERE/hits_poison.jsonl" 2>&1 | tail -1 || true
echo "CAPTURED (a heartbeat before the abort):"; cat "$HERE/hits_poison.jsonl" 2>/dev/null

echo; echo "############ NEXT: let the AI diagnose + fix ############"
cat <<'MSG'
Hand the capture above to Claude with the fr-trace skill loaded (skills/fr-trace):

  length = -9223372036854775808  (LONG_MIN) arriving at addReplyArrayLen.

Claude root-causes `count = -l` overflowing on LONG_MIN and produces the fix
in demos/redis/expected/fix.diff. Then run ./fix-and-verify.sh to prove it.
MSG
