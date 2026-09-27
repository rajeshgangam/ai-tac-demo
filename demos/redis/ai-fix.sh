#!/usr/bin/env bash
# Autonomous AI-TAC loop: capture the poison LIVE, then let the model diagnose,
# patch, rebuild and verify — retrying until the crash is gone.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh" >/dev/null
AITAC="$HERE/../../.fluxdbg-bin/tools/ai-tac"
PROVIDER="${1:-abacus}"
REDIS="$HERE/redis"; NPROC=$(nproc)
echo "== 1. capture the poison value on the live server =="
"$HERE/reproduce.sh" >/tmp/rep.log 2>&1 || true
echo "captured: $(cat "$HERE/hits_poison.jsonl" 2>/dev/null)"
echo "== 2. AI-TAC ($PROVIDER) diagnoses, patches, rebuilds, verifies =="
python3 "$AITAC" --provider "$PROVIDER" fix \
  --source "$REDIS/src/t_set.c" \
  --capture "$HERE/hits_poison.jsonl" \
  --symptom "Redis crashes with an assertion on: SRANDMEMBER myset -9223372036854775808" \
  --build "make -j$NPROC -C '$REDIS' MALLOC=libc OPTIMIZATION=-O0 REDIS_CFLAGS='-g3 -Wno-error'" \
  --verify "bash '$HERE/verify-poison.sh'" \
  --apply
