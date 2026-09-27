#!/usr/bin/env bash
# Apply the fix Claude derived from the capture, rebuild, prove the crash is gone.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDIS="$HERE/redis"; CLI="$REDIS/src/redis-cli"; PORT="${PORT:-7891}"
cd "$REDIS"
echo "== applying fix (bound the parse: getRangeLongFromObjectOrReply -LONG_MAX..LONG_MAX) =="
sed -i 's#if (getLongFromObjectOrReply(c,c->argv\[2\],&l,NULL) != C_OK) return;#if (getRangeLongFromObjectOrReply(c,c->argv[2],-LONG_MAX,LONG_MAX,\&l,NULL) != C_OK) return;#' src/t_set.c
sed -n '/getRangeLongFromObjectOrReply(c,c->argv\[2\]/p' src/t_set.c | head -1
echo "== rebuild =="
make -j"$(nproc)" MALLOC=libc OPTIMIZATION="-O0" REDIS_CFLAGS="-g3 -Wno-error" >/tmp/redis_rebuild.log 2>&1
"$REDIS/src/redis-server" --port "$PORT" --daemonize yes --logfile /tmp/redis_fix.log --save "" >/dev/null 2>&1; sleep 1
PID=$("$CLI" -p "$PORT" info server | awk -F: '/process_id/{gsub(/\r/,"");print $2}')
"$CLI" -p "$PORT" sadd myset a b c d e >/dev/null
echo "== poison on FIXED build =="
"$CLI" -p "$PORT" SRANDMEMBER myset -9223372036854775808
echo "== benign still works =="; "$CLI" -p "$PORT" SRANDMEMBER myset -3
if kill -0 "$PID" 2>/dev/null; then echo "server: ALIVE — fixed, no crash"; else echo "server: DEAD (unexpected)"; fi
"$CLI" -p "$PORT" SHUTDOWN NOSAVE 2>/dev/null || true
