# Redis CVE-2023-25155 — reproduce, capture, fix

A real published CVE. One command crashes the server; `fr trace` captures the
poison value on the **live** process; the AI fixes it from that evidence.

## Run
```bash
source scripts/env.sh
demos/redis/reproduce.sh        # clones+builds the BUGGY redis, crashes it, captures the value
demos/redis/fix-and-verify.sh   # applies the AI-derived fix, rebuilds, proves the crash is gone
```

## What you'll see
```
SRANDMEMBER myset -9223372036854775808   ->  server DEAD (ASSERTION FAILED)

fr trace capture on the live server:
  benign -3   -> {"func":"addReplyArrayLen","vars":{"length":3}}
  poison      -> {"func":"addReplyArrayLen","vars":{"length":-9223372036854775808}}   # LONG_MIN

after fix:  -> ERR value is out of range   (no crash)
```

## The AI step (this is the point)
`reproduce.sh` stops with the captured `length = -9223372036854775808`. Load the
`skills/fr-trace` skill into Claude and hand it that capture + the source. It
root-causes `count = -l` overflowing when `l == LONG_MIN`, and writes the fix in
`expected/fix.diff` — which is **byte-identical to the maintainers' real CVE fix**.

Full narrative: `findings/REDIS-CVE-2023-25155.md`.
