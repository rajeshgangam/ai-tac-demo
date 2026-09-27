#!/usr/bin/env bash
# Attach fr trace to the LIVE ns2 bgpd, capture the BGP UPDATE path, then let
# the AI explain what the running router did — no restart. Run frr-up.sh first.
#   ./frr-trace.sh            # abacus (default) explains the capture
#   ./frr-trace.sh openai     # other provider (needs its key in env)
#   ./frr-trace.sh none       # skip the AI beat (capture only)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh" >/dev/null
FRR=/usr/local/frr; BGPD="$FRR/sbin/bgpd"; PROVIDER="${1:-abacus}"
PID=$(sudo cat /var/run/frr/ns2/bgpd.pid 2>/dev/null)
[ -n "${PID:-}" ] || { echo "ns2 bgpd not running — run demos/frr/frr-up.sh first"; exit 1; }
echo "== live ns2 bgpd pid=$PID =="
SPEC=/tmp/bgp.bin   # ABSOLUTE — the target opens it against its own cwd
tpc_compile "$HERE/bgp.tpc" "$BGPD" -o "$SPEC" | tail -1
sudo chmod 0644 "$SPEC"
echo "== attach probe on bgp_update_receive (no restart) =="
sudo env FR_PROBE_LIB="$FR_PROBE_LIB" "$FR" trace attach "$PID" --spec "$SPEC" \
     --tempcode --ttl-sec 300 --max-hz 20000 </dev/null 2>&1 | tail -2
echo "== trigger a full UPDATE exchange on the live router (clear the session) =="
sudo $FRR/bin/vtysh -N ns2 -c "clear bgp *" >/dev/null 2>&1; sleep 3
sudo $FRR/bin/vtysh -N ns1 -c "clear bgp *" >/dev/null 2>&1; sleep 6
echo "== captured bgp_update_receive events on the LIVE router =="
sudo "$FR" trace collect "$PID" --out "$HERE/hits_bgp.jsonl" 2>/dev/null || true
echo "count: $(grep -c bgp_update_receive "$HERE/hits_bgp.jsonl" 2>/dev/null || echo 0)"
grep bgp_update_receive "$HERE/hits_bgp.jsonl" 2>/dev/null | head -4 | sed 's/^/  /'
sudo "$FR" trace attach "$PID" --remove-all </dev/null >/dev/null 2>&1 || true
echo "== probe removed; router still running =="
# --- AI beat: explain what the live router just did ---
if [ "$PROVIDER" != "none" ] && [ -s "$HERE/hits_bgp.jsonl" ]; then
  echo "== AI-TAC ($PROVIDER): what did the live router just do? =="
  python3 "$HERE/../../.fluxdbg-bin/tools/ai-tac" --provider "$PROVIDER" explain \
    --capture "$HERE/hits_bgp.jsonl" \
    --context "Captured LIVE by fr trace from a running FRR bgpd on the receiving side of an eBGP session (namespace ns2, local AS65002, peer 10.0.0.1 in AS65001). The probe is on bgp_update_receive(struct peer_connection *conn, size_t size): it fires once per BGP UPDATE message received; 'size' is the UPDATE message length in bytes. The session was just cleared to force a re-exchange. The router was never restarted." \
    || echo "(AI explain skipped — needs internet to reach the model)"
fi
