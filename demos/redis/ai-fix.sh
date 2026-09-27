#!/usr/bin/env bash
# AI-TAC: capture the poison value LIVE, then let the model explain the root
# cause and propose a fix. Default = explain + probable fix (fast, no rebuild).
# Add --apply to run the full autonomous loop (patch -> rebuild -> verify -> retry).
#   ./ai-fix.sh                 # abacus, explain + propose
#   ./ai-fix.sh openai          # another provider (needs its key in env)
#   ./ai-fix.sh abacus --apply  # full autonomous apply+verify loop
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh" >/dev/null
AITAC="$HERE/../../.fluxdbg-bin/tools/ai-tac"
PROVIDER="${1:-abacus}"; MODE="${2:-}"
REDIS="$HERE/redis"; NPROC=$(nproc)
echo "== 1. capture the poison value on the live server =="
"$HERE/reproduce.sh" >/tmp/rep.log 2>&1 || true
echo "captured: $(cat "$HERE/hits_poison.jsonl" 2>/dev/null)"
echo "== 2. AI-TAC ($PROVIDER): explain + propose a fix =="
APPLY=()
if [ "$MODE" = "--apply" ]; then
  APPLY=(--apply
    --build "make -j$NPROC -C '$REDIS' MALLOC=libc OPTIMIZATION=-O0 REDIS_CFLAGS='-g3 -Wno-error'"
    --verify "bash '$HERE/verify-poison.sh'")
fi
python3 "$AITAC" --provider "$PROVIDER" fix \
  --source "$REDIS/src/t_set.c" \
  --capture "$HERE/hits_poison.jsonl" \
  --symptom "Redis crashes with an assertion on: SRANDMEMBER myset -9223372036854775808" \
  "${APPLY[@]}"
