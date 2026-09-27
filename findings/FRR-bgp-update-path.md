# AI-TAC evidence bundle

- **generated:** 2026-09-25 21:04:56
- **target pid:** 127433
- **binary:** `/usr/local/frr/sbin/bgpd`
- **symptom:** runtime evidence of the BGP UPDATE receive path on a live eBGP session (ticket class: #14818 nexthop, #6129 MPLS label, #20435 stale config)
- **brain:** direct

## Diagnosis

`bgp_update_receive` executed under the workload: 9 live records captured. Captured values — arg0: 9 samples, e.g. [110796097741088, 110796097741088, 110796097741088]; arg1: 9 samples, e.g. [36, 8, 36]. These are the real arguments the running process saw, with no restart or recompile.

## Evidence — captured live from the running process

```json
{"ts":1248826532157629,"tid":127433,"func":"bgp_update_receive","phase":"entry","pc":"0x64c4a0067806","vars":{"arg0":110796097741088,"arg1":36}}
{"ts":1248827064149699,"tid":127433,"func":"bgp_update_receive","phase":"entry","pc":"0x64c4a0067806","vars":{"arg0":110796097741088,"arg1":8}}
{"ts":1248827600174985,"tid":127433,"func":"bgp_update_receive","phase":"entry","pc":"0x64c4a0067806","vars":{"arg0":110796097741088,"arg1":36}}
{"ts":1248828137567276,"tid":127433,"func":"bgp_update_receive","phase":"entry","pc":"0x64c4a0067806","vars":{"arg0":110796097741088,"arg1":8}}
{"ts":1248828677551141,"tid":127433,"func":"bgp_update_receive","phase":"entry","pc":"0x64c4a0067806","vars":{"arg0":110796097741088,"arg1":36}}
{"ts":1248829213277609,"tid":127433,"func":"bgp_update_receive","phase":"entry","pc":"0x64c4a0067806","vars":{"arg0":110796097741088,"arg1":8}}
{"ts":1248829751110049,"tid":127433,"func":"bgp_update_receive","phase":"entry","pc":"0x64c4a0067806","vars":{"arg0":110796097741088,"arg1":36}}
{"ts":1248830283490793,"tid":127433,"func":"bgp_update_receive","phase":"entry","pc":"0x64c4a0067806","vars":{"arg0":110796097741088,"arg1":8}}
{"ts":1248830809299948,"tid":127433,"func":"bgp_update_receive","phase":"entry","pc":"0x64c4a0067806","vars":{"arg0":110796097741088,"arg1":36}}
```

_9 record(s) captured; the values above came from the process while it kept serving._

## Investigation transcript

```
compile a probe at bgp_update_receive capturing ['arg0', 'arg1'] (tpc-compile, register path)
tpc-compile -> ==> wrote /tmp/ai_tac_127433.tpc.bin (1 probes, 0 warnings, 0 skipped, 0 B templates, 600 bytes total)
fr trace attach 127433 --spec ... --tempcode --ttl-sec 300 --max-hz 20000
attach -> fr trace attach: tempcode injection succeeded
waiting for the workload to exercise the site...
fr trace collect -> 9 record(s)
fr trace attach --remove-all: probes removed, target left running
```

## Provenance & cleanup

- Every value was read from the live process; nothing was restarted or recompiled.
- The probe was placed by build-ID-verified spec; a mismatch would have been refused.
- Probes were removed on completion (probe_detach / --remove-all).

> **Caveat:** flux-dbg has no capture redaction. This bundle may contain sensitive values if a probe sat near one; review before sharing.