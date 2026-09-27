#!/usr/bin/env bash
# Attach fr trace to the LIVE ns2 bgpd, capture the BGP UPDATE path while ns1
# flaps its route — no restart of the router. Run frr-up.sh first.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh" >/dev/null
FRR=/usr/local/frr
BGPD="$FRR/sbin/bgpd"
PID=$(sudo cat /var/run/frr/ns2/bgpd.pid 2>/dev/null)
[ -n "${PID:-}" ] || { echo "ns2 bgpd not running — run demos/frr/frr-up.sh first"; exit 1; }
echo "== live ns2 bgpd pid=$PID (session: $($FRR/bin/vtysh -N ns2 -c 'show ip bgp summary' 2>/dev/null | awk '/10.0.0.1/{print $NF" prefixes, state "$(NF-1)}'))"
SPEC=/tmp/bgp.bin   # ABSOLUTE — the target opens it against its own cwd
tpc_compile "$HERE/bgp.tpc" "$BGPD" -o "$SPEC" | tail -1
sudo chmod 0644 "$SPEC"
echo "== attach probe on bgp_update_receive (no restart) =="
sudo env FR_PROBE_LIB="$FR_PROBE_LIB" "$FR" trace attach "$PID" --spec "$SPEC" \
     --tempcode --ttl-sec 300 --max-hz 20000 </dev/null 2>&1 | tail -2
echo "== trigger a full UPDATE exchange on the live router (clear the session) =="
# a gentle network flap is throttled by eBGP MRAI (~30s); clearing the session
# forces bgpd to receive its peer's routes again immediately.
sudo $FRR/bin/vtysh -N ns2 -c "clear bgp *" >/dev/null 2>&1
sleep 3
sudo $FRR/bin/vtysh -N ns1 -c "clear bgp *" >/dev/null 2>&1
sleep 6
echo "== captured bgp_update_receive events on the LIVE router =="
sudo "$FR" trace collect "$PID" --out "$HERE/hits_bgp.jsonl" 2>/dev/null || true
echo "count: $(grep -c bgp_update_receive "$HERE/hits_bgp.jsonl" 2>/dev/null || echo 0)"
grep bgp_update_receive "$HERE/hits_bgp.jsonl" 2>/dev/null | head -4 | sed 's/^/  /'
sudo "$FR" trace attach "$PID" --remove-all </dev/null >/dev/null 2>&1 || true
echo "== probe removed; router still running =="
