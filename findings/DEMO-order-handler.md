# AI-TAC evidence bundle

- **generated:** 2026-09-25 20:51:59
- **target pid:** 127125
- **binary:** `/tmp/svc/app`
- **symptom:** order handler intermittently slow (hackathon demo target)
- **brain:** direct

## Diagnosis

`handle_order` executed under the workload: 248 live records captured. Captured values — arg0: 248 samples, e.g. [109, 110, 111]; arg1: 248 samples, e.g. [2, 3, 4]. These are the real arguments the running process saw, with no restart or recompile.

## Evidence — captured live from the running process

```json
{"ts":1248049753799654,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":109,"arg1":2}}
{"ts":1248049774054953,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":110,"arg1":3}}
{"ts":1248049794273256,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":111,"arg1":4}}
{"ts":1248049814519286,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":112,"arg1":5}}
{"ts":1248049834659384,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":113,"arg1":6}}
{"ts":1248049854785445,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":114,"arg1":7}}
{"ts":1248049874933818,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":115,"arg1":8}}
{"ts":1248049895067909,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":116,"arg1":9}}
{"ts":1248049915313883,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":117,"arg1":1}}
{"ts":1248049935557152,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":118,"arg1":2}}
{"ts":1248049955719665,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":119,"arg1":3}}
{"ts":1248049975880899,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":120,"arg1":4}}
{"ts":1248049996055005,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":121,"arg1":5}}
{"ts":1248050016296222,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":122,"arg1":6}}
{"ts":1248050036544880,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":123,"arg1":7}}
{"ts":1248050056699340,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":124,"arg1":8}}
{"ts":1248050076942063,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":125,"arg1":9}}
{"ts":1248050097089542,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":126,"arg1":1}}
{"ts":1248050117348943,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":127,"arg1":2}}
{"ts":1248050137598527,"tid":127125,"func":"handle_order","phase":"entry","pc":"0x60ae418ee1a9","vars":{"arg0":128,"arg1":3}}
```

_248 record(s) captured; the values above came from the process while it kept serving._

## Investigation transcript

```
compile a probe at handle_order capturing ['arg0', 'arg1'] (tpc-compile, register path)
tpc-compile -> ==> wrote /tmp/ai_tac_127125.tpc.bin (1 probes, 0 warnings, 0 skipped, 0 B templates, 600 bytes total)
fr trace attach 127125 --spec ... --tempcode --ttl-sec 300 --max-hz 20000
attach -> fr trace attach: tempcode injection succeeded
waiting for the workload to exercise the site...
fr trace collect -> 248 record(s)
fr trace attach --remove-all: probes removed, target left running
```

## Provenance & cleanup

- Every value was read from the live process; nothing was restarted or recompiled.
- The probe was placed by build-ID-verified spec; a mismatch would have been refused.
- Probes were removed on completion (probe_detach / --remove-all).

> **Caveat:** flux-dbg has no capture redaction. This bundle may contain sensitive values if a probe sat near one; review before sharing.