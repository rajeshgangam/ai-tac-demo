---
name: fr-trace
description: >-
  Trace a live process with flux-dbg end to end: pick a function, write or
  auto-generate a .tpc probe spec, compile it against the target binary,
  attach to the running process, capture arguments/locals/timings, and remove
  the probes cleanly. Use when you want to observe what a running program is
  doing — in C, C++, Rust, Go, or a managed runtime — without restarting or
  recompiling it. Covers stripped binaries, containers, CET-hardened builds,
  and the guardrails that keep a probe from becoming an incident.
---

# fr trace — the whole loop, for anyone

You have a process running. You want to see what a function is actually doing —
its arguments, a local, how long it takes — without stopping or rebuilding it.
That is `fr trace`. This skill is the complete path, including generating the
`.tpc` spec, and the traps that waste the most time.

## The five steps

```bash
# 1. find the function's address in the binary (usually automatic)
# 2. write a .tpc spec (JSON) — or auto-generate one
# 3. compile it against the exact binary the process is running
fr tpc compile probes.tpc /path/to/binary -o probes.bin
# 4. attach, ALWAYS with a blast radius
sudo FR_PROBE_LIB=/usr/local/lib/libfr_probe.so \
     fr trace attach <pid> --spec probes.bin --tempcode --ttl-sec 300 --max-hz 20000
# 5. drive load, drain, then remove
fr trace collect <pid> --out hits.jsonl
fr trace attach <pid> --remove-all
```

## Two different jobs: generating a .tpc vs compiling it

This is the single thing most likely to confuse you, and it is the root of the
most common garbage-output bug. There are two separate steps, and people
conflate them:

- **Generating the .tpc** — deciding *what* to capture. Three ways:
  1. **Hand-write it** (JSON, below). Full control, no surprises.
  2. **`fr tpc auto`** — the machine writes the .tpc from the binary's DWARF.
  3. **The `fr-web` workbench** — the same DWARF engine as `fr tpc auto`, but
     you pick sites and variables in a browser and it emits the .tpc. This is
     what the FRR demo used.
- **Compiling the .tpc** — `fr tpc compile <spec.tpc> <binary> -o <spec.bin>`.
  Turns *any* .tpc (hand-written or auto-generated) into the binary `.bin` the
  target reads. **You always run this step.** Generation is optional and
  upstream of it.

```
hand-written .tpc  ─┐
fr tpc auto        ─┼─►  fr tpc compile  ─►  .bin  ─►  fr trace attach
fr-web workbench   ─┘        (always)
```

**The trap:** the auto-generators (`fr tpc auto` and `fr-web`) tend to emit
*every in-scope variable* at the function's entry. But at `"kind":"entry"`
only the ARGUMENTS hold real values — the locals have not been assigned yet.
So an auto-generated entry spec with a dozen captures typically yields two good
values (the args) and ten fields of uninitialized-stack noise. This is not a
bug in the probe; the capture faithfully reads what the generator asked for.
Fixes: keep only the arguments at entry, or move the local captures to a body
line (`addr`) or to `exit`. A hand-written 2-argument spec is often cleaner
than a 13-capture auto one.

## Before you touch anything: the three that fail silently

These cost more debugging time than everything else combined. Check them first.

1. **The build-ID must match.** A `.tpc`'s probe sites are file offsets valid
   only for the one build they were compiled against. `fr` bakes the target's
   GNU build-ID into the `.bin` and **refuses** to patch a process whose binary
   differs. If you rebuilt or redeployed, recompile the spec. A mismatch is a
   loud refusal, not a silent corruption — but a *stale* spec against a
   *rebuilt* binary is the classic own-goal.

2. **The target reads the probe library AND the spec as ITS OWN user.** The
   injected `libfr_probe.so` is opened by the target process, not by you. A
   `.so` under `/root` is invisible to an nginx worker running as `www-data`,
   and the error is a bare `remote open ... failed: -13`. Put the probe lib and
   the spec somewhere the target's user can read (`/usr/local/lib`, mode 0644),
   and remember `sudo` strips env vars — use `sudo env FR_PROBE_LIB=...`.

3. **The probe logs to the TARGET's stderr, not your terminal.** When an
   attach "succeeds" but captures nothing, the reason is in the target's
   stderr — which for a supervised daemon means **syslog**, not your shell.
   `grep tracepoint /var/log/syslog` (or `journalctl`) answers it immediately:
   "short read on header", "BUILD-ID MISMATCH", "cannot open .tpc spec".

## Writing a .tpc by hand

A `.tpc` is JSON. Minimal, one entry probe capturing the first two arguments:

```json
{
  "service": "myapp",
  "name": "trace1",
  "probes": [
    {
      "kind": "entry",
      "func": "handle_request",
      "id": "handle_request",
      "captures": [
        { "name": "req",  "reg": "arg0" },
        { "name": "size", "reg": "arg1" }
      ]
    }
  ]
}
```

### Probe fields

| field | meaning |
|---|---|
| `kind` | `entry` (on call), `exit` (at RET, `rax` = return value), `span` (both, with duration) |
| `func` | the symbol name — **mangled** for C++ (`_ZN4swss6Select6selectE...`), package-qualified for Go (`net/http.(*conn).serve`), plain for C |
| `id` | a label for this probe in the output's `func` field |
| `addr` | optional: an explicit vaddr (hex string or int) — overrides symbol lookup, for line-precision sites |
| `module_hint` / `module` | for a function in a shared library: which `.so` it lives in; `module` points at a readable copy to take the build-ID from |
| `sample_rate` | fire 1-in-N (caps volume on a hot path) |
| `captures` | list of values to record (below) |

### Capture kinds (the `kind` field of each capture)

| kind | reads | use for |
|---|---|---|
| `register` (default when only `reg` given) | a register verbatim | integers, pointers, sizes |
| `string` / `c-str` | a null-terminated C string at the address | `char *` |
| `reg-deref` | dereference a register once | `int *`, struct field via offset |
| `stack` | `[rbp + offset]`, with `size` | a specific stack slot |
| `memory` / `mem-fileoff` | an absolute vaddr / a file-offset global | globals |
| `go-str`, `go-slice`, `go-iface` (+ `-reg`) | Go's fat-pointer layouts | Go strings/slices/interfaces |

Registers by role: **`arg0`–`arg7`** (portable across architectures — resolves
to `rdi/rsi/...` on x86-64, the right ones on aarch64/riscv), or name them
directly (`rdi`, `rsi`, `rax`). Prefer `argN` so the spec is portable.

### The single most common capture mistake

**At `"kind":"entry"`, only the ARGUMENTS are valid.** Locals declared inside
the function are not yet assigned, so capturing them at entry reads
uninitialized stack — plausible-looking garbage. To capture a local, use a
later `addr` (a body line past the assignment) or capture at `exit`. See
"generating vs compiling" above — this is the trap the auto-generators fall
into.

## When the binary was built on another machine (different path)

The binary's DWARF records where it was *compiled* (a CI path like
`/build/app-1.4`), not where your source is now (`/home/me/app`). So source
resolution fails, or a basename search silently finds the wrong same-named
file. Fix it deterministically -- the reverse of `-fdebug-prefix-map`:

```bash
# find the build prefix the binary remembers
readelf --debug-dump=info app | grep -m1 comp_dir     # -> /build/app-1.4

# map it to your checkout (fr-web and fr-binary-index both take --path-map)
fr tpc auto --binary app --at handler:42 --format '{req}' --out p.tpc  # uses DWARF; path only matters for VIEWING source
tools/fr-binary-index app --source handler --path-map /build/app-1.4=/home/me/app
tools/fr-web app --path-map /build/app-1.4=/home/me/app --source-root /home/me/app --run
```

`--path-map` is applied before any heuristic, so it wins over the ambiguous
basename fallback. Repeat it per build prefix (vendored deps have their own).
Note: this only affects finding SOURCE TEXT to view; the probe addresses come
from DWARF/symbols and are correct regardless.

## Auto-generating a .tpc

If you do not want to hand-write offsets:

```bash
# from DWARF: resolve a function, a source line, or a variable by name
fr tpc auto --binary /path/to/binary --at 'handle_request' --format '{req} {size}' --out probes.tpc
```

`fr tpc auto` reads the binary's DWARF (or its separate debug file, found via
build-ID or `.gnu_debuglink`) and produces a spec with real capture locations,
including line-precision sites and capture-by-variable-name. Then compile it as
in step 3. For C++ it demangles for you; for Rust it handles the module-path
namespacing; for a GraalVM native-image it follows the declaration/definition
DWARF split.

## Compiling

```bash
fr tpc compile probes.tpc /path/to/binary -o probes.bin
# expect: "wrote probes.bin (N probes, 0 warnings, 0 skipped)"
```

If it says **"0 probes emitted"**, read the warnings — the symbol did not
resolve. Common causes: the binary is stripped and the symbol is neither
exported nor in a debug file (pass the debug file as the binary, or use `addr`);
or it is an optimiser clone (`foo.isra.0`, `foo.lto_priv.0`) — those are
joined automatically, but verify.

## Attaching, with guardrails (non-negotiable on anything live)

```bash
sudo env FR_PROBE_LIB=/usr/local/lib/libfr_probe.so \
  fr trace attach <pid> --spec probes.bin --tempcode \
      --ttl-sec 300 --max-hz 20000 --out hits.jsonl
```

- `--ttl-sec N` — probes go inert N seconds after they load, so an attach
  nobody remembers stops costing anything. Enforced **inside the target**, so
  it holds even if your terminal dies.
- `--max-hz N` — any single site over N hits/sec disables itself. For the probe
  that turns out to sit on a per-packet path.
- `--tempcode` — the default injection (no ptrace stop, no dlopen). `--dlopen`
  is the fallback.
- `--out FILE` — spawn a collector that drains the ring to a file. Without it,
  drain manually with `fr trace collect`.

Never attach to a live service without `--ttl-sec` and `--max-hz`.

## Collecting

```bash
fr trace collect <pid>                 # print records
fr trace collect <pid> --out hits.jsonl
```

Each hit is one NDJSON line:

```json
{"ts":417450623818043,"tid":204354,"func":"handle_request","phase":"entry","pc":"0x...","vars":{"req":105051598014384,"size":36}}
```

**An empty ring is a result, not a failure.** It means the code did not run,
the site was wrong (inlined away, wrong overload, a declaration DIE), or the
condition never held — three different things. Say which you think it is.

## Removing

```bash
fr trace attach <pid> --remove-all
```

Restores the original bytes. The process keeps running. Always do this when
done; the TTL is a safety net for when you cannot, not a substitute.

## Containers (SONiC, Kubernetes, any Docker target)

Everything the tool aims at is often containerised, and paths resolve in the
**target's** namespace, not yours:

- Put the probe lib and spec at a real path inside the container
  (`docker cp x ctr:/usr/local/lib/x` — **not** `/tmp`, which is a tmpfs mount
  where `docker cp` silently writes into the layer underneath and the file
  never appears).
- The target has its own `/dev/shm`; recent `fr` writes the guard file and
  finds the ring there automatically (via `/proc/<pid>/root/dev/shm`).
- The ring is named by the target's **namespace-local** pid; `fr trace collect
  <host-pid>` reads the innermost `NSpid` and finds it.
- To resolve symbols when the container ships no binutils, copy the binary out
  via `/proc/<pid>/root/usr/...`, resolve where the tools are, send the spec
  back. That is the real support workflow.

## Hardened binaries (Intel CET)

If the target is built `-fcf-protection` with a shadow stack armed, `fr tpc
compile` detects it from the ELF notes and places exit probes at RET sites
(a return-address swap would be ROP-shaped and the CPU would kill the process).
Automatic — nothing to configure.

## What fr trace will NOT do — state these, do not work around them

- **No redaction.** A capture emits whatever is at the address. A probe on an
  auth or credential path will capture tokens into `hits.jsonl`. Choose sites
  accordingly; on someone else's system, avoid credential paths entirely.
- **No conditional capture yet** (only `sample_rate`). Capture and filter after.
- **No recording of a crashing program.** `fr trace` is for live processes;
  crash record/replay is a separate, limited path.
- **Linux only.** macOS/Windows targets are out of scope for native attach.

## A complete worked example (real, from a live FRR bgpd)

```bash
# 1. spec: trace bgp_update_receive, capture the two arguments (valid at entry)
cat > bgp.tpc <<'JSON'
{ "service":"frr","name":"bgp","probes":[
  {"kind":"entry","func":"bgp_update_receive","id":"bgp_update_receive",
   "captures":[{"name":"connection","reg":"arg0"},{"name":"size","reg":"arg1"}]}]}
JSON

# 2. compile against the running bgpd
fr tpc compile bgp.tpc /usr/local/frr/sbin/bgpd -o bgp.bin
#   -> wrote bgp.bin (1 probes, 0 warnings, 0 skipped)
#   -> note: bgpd is -fcf-protection (SHSTK): exit probes at RET sites

# 3. make lib + spec readable by bgpd's user, then attach with guardrails
sudo install -m0644 bgp.bin /usr/local/share/fluxdbg/bgp.bin
sudo env FR_PROBE_LIB=/usr/local/lib/libfr_probe.so \
  fr trace attach $(pgrep -x bgpd) --spec /usr/local/share/fluxdbg/bgp.bin \
      --tempcode --ttl-sec 300 --max-hz 20000

# 4. drive a real BGP UPDATE (flap a route on the peer), then collect
fr trace collect $(pgrep -x bgpd) --out hits.jsonl
#   {"func":"bgp_update_receive","vars":{"connection":0x..,"size":36}}   size=36 = a real UPDATE

# 5. remove
fr trace attach $(pgrep -x bgpd) --remove-all
```

## Managed runtimes are different commands

`fr trace attach` is for native binaries (C/C++/Rust/Go, and native
interpreter functions). For JavaScript source-level tracing use the runtime
clients instead — `fr attach-node` (V8/Node) or `fr attach-bun`
(JavaScriptCore/Bun) with a probes JSON of `{file,line,name,captures}` — and
for the JVM the JVMTI path. The `.tpc` flow above is the native path.
