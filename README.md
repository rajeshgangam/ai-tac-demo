# AI-TAC demo — live-trace a running process, let the AI fix it

Attach to a **running** program, capture what a function is actually doing —
arguments, locals, timings — **without restarting, recompiling, or adding a
printf**. Then hand the captured evidence to an AI (the `fr-trace` skill) so it
diagnoses and fixes the bug from ground truth, not guesswork.

This repo is the demo scaffolding. The tracing engine (`fr`, `libfr_probe.so`,
`tpc-compile`) is **proprietary** and lives in a **separate private repo**
(`ai-tac-demo-bin`); `scripts/setup.sh` pulls it in.

## Quick start (Linux x86-64)
```bash
git clone git@github.com:rajeshgangam/ai-tac-demo.git && cd ai-tac-demo
sudo ./scripts/setup.sh          # pulls the private binaries, installs the probe lib, enables ptrace
source scripts/env.sh            # exports $FR, tpc_compile(), $FR_PROBE_LIB

demos/redis/reproduce.sh         # <-- start here
```
You need read access to the private `ai-tac-demo-bin` repo (ask the owner for an invite).

## The demos
| Demo | What it shows |
|---|---|
| **demos/redis** | A real CVE. One command crashes Redis; `fr trace` captures the overflow value (`LONG_MIN`) on the live server a heartbeat before the abort; the AI's fix is byte-identical to the maintainers'. |
| **demos/frr** | Same loop against a live `bgpd` router — the BGP UPDATE path, no restart. |
| **findings/** | Honest write-ups of each investigation, incl. one ticket that *does not reproduce* on current dev (a real triage outcome, not a staged win). |

## The AI skill
`skills/fr-trace/SKILL.md` is the full loop for an AI agent: pick a function,
generate/compile a `.tpc` probe spec, attach with guardrails, capture, remove.
Load it into Claude and point it at a process — it drives `fr` end to end.

## Two traps that fail *silently* (attach still says "success")
1. **Build-ID must match** — a `.tpc` is compiled against one exact build; `fr`
   refuses a mismatched process. Recompile after any rebuild.
2. **The `--spec` path must be ABSOLUTE** — the target process opens it against
   *its own* cwd, not yours. A relative path resolves to nothing, no ring is
   created, and nothing is captured — with no error on your side.

## Honest limits
- Needs a `-g`/symbol build to name source variables; register/stack captures
  work on stripped binaries too.
- **No redaction** — a capture emits whatever is at the address. Don't probe
  credential paths.
- Native (C/C++/Rust/Go) here; Node/Bun/JVM source-level tracing use their own
  `fr attach-*` paths.

## License
Proprietary — All Rights Reserved (see `LICENSE`/`NOTICE`). Public visibility is
not a license to use, copy, or redistribute. © 2026 Rajesh Gangam.
