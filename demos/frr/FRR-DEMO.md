# FRR bgpd — live-trace a running router (no restart)

Real FRR (zebra+bgpd, built -O0 -g3) in two network namespaces running eBGP.
Attach `fr trace` to the live `bgpd` and watch the BGP UPDATE path.

## Run
```bash
source scripts/env.sh
sudo demos/frr/frr-up.sh          # bring up ns1<->ns2 eBGP (real zebra+bgpd)
demos/frr/frr-trace.sh            # attach to live bgpd, flap a route, capture UPDATEs
demos/frr/frr-down.sh             # tear down
```

## What you'll see
`bgp_update_receive` captured on the live router as ns1 flaps 172.16.1.0/24 —
`{"conn":...,"size":...}` per UPDATE, then **AI-TAC narrates** what the live router did (decodes the UPDATE sizes, spots End-of-RIB, etc.) — router never restarted.

`./demos/frr/frr-trace.sh openai` uses another provider; `./demos/frr/frr-trace.sh none` skips the AI beat.

## Source-level demo (the workbench)
The FRR source is at `/root/frr` (matches the binary's DWARF). Browse functions
and generate `.tpc` specs against `/usr/local/frr/sbin/bgpd`:
```bash
sudo .fluxdbg-bin/tools/fr-web /usr/local/frr/sbin/bgpd --source-root /root/frr --run
# open http://127.0.0.1:8770
```
