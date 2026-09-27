# source this:  source scripts/env.sh
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BINROOT="$REPO/.fluxdbg-bin"
if [ ! -d "$BINROOT" ]; then echo "run scripts/setup.sh first (binaries not present)"; return 1 2>/dev/null || exit 1; fi
export PY="$BINROOT/python-runtime/bin/python3"
export PYTHONPATH="$BINROOT/python:$BINROOT/vendor"
export FR="$BINROOT/build/fr"
export FR_PROBE_LIB="${FR_PROBE_LIB:-/usr/local/lib/libfr_probe.so}"
tpc_compile() { "$PY" "$BINROOT/tools/tpc-compile" "$@"; }
export -f tpc_compile 2>/dev/null || true
echo "[env] FR=$FR"
echo "[env] FR_PROBE_LIB=$FR_PROBE_LIB   (must be readable by the TARGET's user)"
