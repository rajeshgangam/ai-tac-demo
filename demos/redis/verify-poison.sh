#!/usr/bin/env bash
# exit 0 if the poison command does NOT crash the server (fixed); 1 if it crashes.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; REDIS="$HERE/redis"; PORT=7899
"$REDIS/src/redis-server" --port $PORT --daemonize yes --logfile /tmp/verify.log --save "" >/dev/null 2>&1
sleep 1
PID=$("$REDIS/src/redis-cli" -p $PORT info server 2>/dev/null | awk -F: "/process_id/{gsub(/\r/,\"\");print \$2}")
"$REDIS/src/redis-cli" -p $PORT sadd myset a b c d e >/dev/null 2>&1
"$REDIS/src/redis-cli" -p $PORT SRANDMEMBER myset -9223372036854775808 >/dev/null 2>&1
sleep 1
if kill -0 "$PID" 2>/dev/null; then
  "$REDIS/src/redis-cli" -p $PORT SHUTDOWN NOSAVE >/dev/null 2>&1
  echo "server SURVIVED the poison command — FIXED"; exit 0
else
  echo "server CRASHED on the poison command — still buggy"; exit 1
fi
