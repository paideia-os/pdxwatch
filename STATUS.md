# pdxwatch -- status

**Wave:** R102 userland graphical stack -- reference apps
**Current milestone:** v1.1-C release closer landed (pdxwatch#13) -- **v1.1.0 released**
**Version:** 1.1.0 (Track-C release; M5-001 v1.0.0 signed-release
closer remains a downstream milestone -- 1.1.0 reflects the
Track-C real-body + semantic-pipe wave landing ahead of the
graphical-stack completion)

See [`paideia-os` monorepo `design/graphics/r102-user-plan.md`](https://github.com/paideia-os/paideia-os/blob/main/design/graphics/r102-user-plan.md)
§2.8 (system-monitor GUI: role + data source + widget layout) and
§4.8 (per-issue landing plan) for the full spec and milestone/
issue breakdown.

## Milestones

| Milestone | Scope | Status |
|---|---|---|
| M1-001 | Scaffold + `sys_taskinfo` aggregation collectors + Main::main dispatch loop | **landed 2026-09-07 (v1.1-A)** |
| M1-002 | `caps.decl` window opening + 480x360 KIND_SURFACE + argv parser | pending libpdx-gfx M1 |
| M2-001 | CPU bar-per-core widget | pending libpdx-gfx M2 + libpdx-font M2 |
| M2-002 | Memory tri-color widget | pending libpdx-gfx M2 |
| M2-003 | Network sparkline widget | pending libpdx-gfx M2 |
| M3-001 | Click-cycle CPU detail + `q` quit | pending libpdx-event M3 |
| M4-001 | Seeded-stat render smoke witness | pending M2 |
| M4-002 | Click-cycle smoke | pending M3 |
| M4-003 | `q`-quit smoke | pending M3 |
| M5-001 | Signed 1.0.0 release | pending M4 |
| v1.1-B | `SysStatRecord@0.1` semantic-pipe emission wire (pdxwatch#12) | **landed 2026-09-08** |
| v1.1-C | Release closer v1.1.0 + tag (pdxwatch#13) | **landed 2026-09-08 (v1.1.0 tagged)** |

## v1.1-A "real-body extraction" landing details (pdxwatch#11)

The R102.M1-001 issue text (pdxwatch#1) named a returns-0 stub as
the initial scaffold. The v1.1-A pass retires that stub concept and
lands the real syscall path directly:

- `src/collectors.pdx` (new, `module Collectors`): CollectSnapshot
  struct + collect_init + collect_tick. The real body wires
  sys_taskinfo (SC+ sysno 83) + sys_clock_read_ns (SC+ sysno 66)
  into an aggregate snapshot -- total CPU-ticks, total RSS in KiB,
  per-state task counts, per-CPU active-task buckets. Same
  syscall pair postui-top's poll module uses; both consumers share
  the KIND_SYS_STAT-less "read the task_pool directly and
  aggregate client-side" posture r102-user-plan.md §2.8 flagged.
- `src/main.pdx` (new, `module Main`): Main::main dispatch entry.
  Runs collect_init(&_pw_snapshot, PW_MAIN_INTERVAL_TICKS=60) then
  a bounded 32-iterate loop over collect_tick, then sys_exit(0).
  The bounded shape is deliberately witness-testable; M3-001's 'q'
  keydown will replace it with an unbounded loop that exits on
  user input.
- `caps.decl` (new): KIND_SURFACE(mint,commit,revoke) +
  KIND_IPC_ENDPOINT(subscribe) + KIND_MEMORY(mint,revoke) forward
  declarations. syscalls block declares sysno 66 + sysno 83.
  declares_output_schemas forward-declares SysStatRecord@0.1 for
  the v1.1-B emitter.
- `manifest.pdxproj` (new): kind = tool, entry = Main::main
  (forward-declared until M1-005), sources: block seeds
  src/collectors.pdx + src/main.pdx, deps: libpdx-gfx / libpdx-
  event / libpdx-font at ^0.1, compliance: block enumerates the
  six paideia-as invariants (module-basename-pascal, no-test-
  mnemonic, cmp-imm32-only, r11-scratch, byte-load-zero-then-mov_b,
  sysv-push-pop-parity).
- `tools/build.sh` (new): per-repo build script mirroring postui-
  top's shape. Compiles src/*.pdx + tests/*.pdx into loose ELF64
  objects under build-out/ via `paideia-as build --emit elf64`.
  Requires paideia-as >= 0.36.0 (encoder floor for the mnemonic
  surface this landing exercises).
- Error-band claim: pdxwatch#11 claims 0xFFFFE200..0xFFFFE20F
  (postui-top holds 0xFFFFE000..0xFFFFE00F; the 0xFFFFE100..
  0xFFFFE1FF page is populated by a mature kind's tail sentinels).
  The full 0xFFFFE200..0xFFFFE2FF page is claim-free per a
  `grep -rhnE '0xFFFFE2[0-9A-F][0-9A-F]' src/ design/` audit at
  landing time, so pdxwatch reserves headroom to 0xFFFFE2FF for
  M1-002+ growth.

## v1.1-B "semantic-pipe emit wire" landing details (pdxwatch#12)

Wires the `SysStatRecord@0.1` producer path through SC+ sysno 115
(`sys_semantic_send`). Kernel body at paideia-os
`src/kernel/core/syscall/handlers/sys_semantic_send.pdx`
(R107-M0-001 landing, paideia-os#2350) is live at HEAD.

Changes:

- `src/collectors.pdx` extended with:
  - `pw_sys_semantic_send(schema, record_ptr, record_len)` wrapper
    for sysno 115.
  - `PW_SEMANTIC_SCHEMA_SSTA = 0x41545353` schema tag (4-char ASCII
    `'SSTA'` little-endian, per postui `SEMANTIC_SCHEMA_<TAG>`
    convention; transitional until libpdx-semantic-pipe's BLAKE3-
    hash schema registry lands).
  - `PW_SEMANTIC_RECORD_OFF = 32` and
    `PW_SEMANTIC_RECORD_BYTES = 160` constants naming the wire slice.
  - `PW_SNAP_OFF_SEMANTIC_EMIT_OK  = 192` and
    `PW_SNAP_OFF_SEMANTIC_EMIT_FAIL = 200` observability counters
    inside the CollectSnapshot reserved region.
  - `PW_ERR_EMIT_EFAULT / PW_ERR_EMIT_EINVAL` sentinel reservations
    within the pdxwatch error band (unused at v1.1-B; reserved for a
    future round that surfaces emit errors up through the M2 render
    path).
  - Phase D-bis emit block in `collect_tick` between the aggregate-
    commit (Phase D) and the tick-anchor (Phase E). The emitted
    record is the 160-byte contiguous slice `[state_ptr + 32 ..
    state_ptr + 192)` -- byte-for-byte prefix of the CollectSnapshot
    fields the schema names, so no marshalling buffer is needed.
    On rax == 0 the emit_ok counter increments; on rax != 0 the
    emit_fail counter increments; the tick still commits either way
    (best-effort emit).

- `caps.decl` `SysStatRecord@0.1` field enumeration tightened to
  match the wire (task_seen + task_skipped added; total 160B; the
  earlier "144B" figure was an off-by-N in the v1.1-A forward-
  declaration). `syscalls:` block gains `sys_semantic_send @ 115`.

- `manifest.pdxproj`'s speculative
  `# - src/semantic_emit.pdx` forward-declaration retired; v1.1-B
  keeps the emit path inside `src/collectors.pdx` (single caller,
  no reuse surface -- extracting would fragment the round without
  benefit).

- Fingerprint: pdxwatch's console/render surface is unchanged.
  The semantic pipe is an out-of-band structured emit channel; no
  duplicate write of any terminal / KIND_SURFACE payload.

## v1.1-C "release closer" landing details (pdxwatch#13)

Closes the Track-C wave. Version bump + tag only -- no source /
caps.decl churn.

- `CHANGELOG.md` (new, repo root): Keep-a-Changelog-style entry
  for `[1.1.0] - 2026-09-08` enumerating v1.1-A (real syscall
  body extraction) + v1.1-B (semantic-pipe emit wire). Sets the
  category shape (Added / Changed / Removed / Notes) forward
  releases inherit.
- `manifest.pdxproj` `version = 1.0.0` -> `version = 1.1.0`. The
  M5-001 forward-declaration placeholder gives way to the actual
  Track-C release version; the signed-release closer at M5-001
  remains a downstream milestone in its own right.
- `STATUS.md` (this file): v1.1-C row flipped to `**landed**`,
  header `Version:` line bumped to 1.1.0, this landing-details
  section added.
- Tag command (run by main, not this landing): `git tag -a v1.1.0
  -m "pdxwatch v1.1.0 -- real syscalls + semantic-pipe emit"`.

## Dependencies

- `paideia-as >= 0.36.0` at compile time (per `manifest.pdxproj` +
  `tools/build.sh` version floor).
- `paideia-os/libpdx-gfx` v0.1 (M1) -- M1-002 wire-in (surface_open
  for the 480x360 back-buffer).
- `paideia-os/libpdx-event` v0.1 (M3) -- M3-001 wire-in (event_next
  for click-cycle + 'q' keydown).
- `paideia-os/libpdx-font` v0.1 (M2) -- M2-001..M2-003 wire-in
  (gfx_draw_glyph label rendering).

## Post-v1.1-C roadmap

- M1-005: `_start` binder + Main::main call frame; produces a
  linkable ELF at build-out/pdxwatch.
- M2 wave: CPU / mem / net widgets against libpdx-gfx M2.
- M3-001: libpdx-event M3 wire-in (click-cycle + 'q' quit).
- M4 witness triplet: seeded-stat, click-cycle, keyboard-quit.
- M5-001: signed 1.0.0 release closer.

## License

MIT -- see LICENSE.
