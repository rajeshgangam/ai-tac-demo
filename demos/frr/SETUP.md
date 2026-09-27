# FRR bgpd live-trace demo

Attach to a running `bgpd` and watch the BGP UPDATE path — no restart of the
router. This is the same loop as the Redis demo against a real routing daemon.

## Get a bgpd with symbols
Either build FRR from source (`./bootstrap.sh && ./configure --enable-dev-build
&& make`), or run the official container and copy in a `-g` build. You need the
symbols for `bgp_update_receive` / `bgp_find_or_add_nexthop` etc.

## Bring up a session
Two namespaces (or two containers) with an eBGP session and something to
advertise. A minimal unnumbered IPv6 link-local peering:
```
# each side:  neighbor <veth> interface remote-as external
#             neighbor <veth> capability extended-nexthop
# one side advertises a prefix (network / redistribute connected)
```

## Attach and capture
```bash
source scripts/env.sh
PID=$(pgrep -n bgpd)
tpc_compile demos/frr/bgp.tpc /path/to/bgpd -o /tmp/bgp.bin      # ABSOLUTE spec path
sudo env FR_PROBE_LIB=$FR_PROBE_LIB "$FR" trace attach $PID \
     --spec /tmp/bgp.bin --tempcode --ttl-sec 300 --max-hz 20000
# drive a route flap, then:
"$FR" trace collect $PID --out demos/frr/hits.jsonl
```

Real captured evidence + the resolved-nexthop procedure:
`findings/FRR-bgp-update-path.md` and `findings/FRR-14818.md`.

> The daemon on the Hetzner demo VM is reached via an ssh host alias; keep
> hostnames/keys out of this public repo.
