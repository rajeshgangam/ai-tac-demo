#!/usr/bin/env bash
# One-time setup: pull the proprietary flux-dbg binaries (PRIVATE repo) and
# install the probe library. You need read access to the private repo.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BINREPO_URL="${FLUXDBG_BIN_REPO:-git@github.com:rajeshgangam/ai-tac-demo-bin.git}"
DEST="$REPO/.fluxdbg-bin"

if [ ! -d "$DEST/.git" ]; then
  echo "[setup] cloning binaries from $BINREPO_URL"
  git clone --depth 1 "$BINREPO_URL" "$DEST"
else
  echo "[setup] updating binaries"; git -C "$DEST" pull --ff-only || true
fi

LIB=/usr/local/lib/libfr_probe.so
if [ "$(id -u)" = 0 ]; then
  install -m0644 "$DEST/build/libfr_probe.so" "$LIB" && echo "[setup] probe lib -> $LIB"
  sysctl -w kernel.yama.ptrace_scope=0 >/dev/null 2>&1 || true
else
  echo "[setup] run as root once to install the probe lib + enable ptrace:"
  echo "        sudo install -m0644 $DEST/build/libfr_probe.so $LIB"
  echo "        sudo sysctl -w kernel.yama.ptrace_scope=0"
fi
echo "[setup] done. Now:  source scripts/env.sh"
