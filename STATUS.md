# pdxwatch -- status

**Wave:** R102 userland graphical stack -- reference apps
**Current milestone:** M1-001 real-body landed (v1.1-A pass; pdxwatch#11)
**Version:** 0.1.0-pre (pre-M5 release closer)

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
| v1.1-B | `SysStatRecord@0.1` semantic-pipe emission wire (pdxwatch#12) | pending v1.1-A + sysno 115 kernel body (paideia-os#2352) |
| v1.1-C | Release closer v1.1.0 + tag (pdxwatch#13) | pending v1.1-A + v1.1-B |

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

## Kernel-body caveat (v1.1-B pending)

The `SysStatRecord@0.1` semantic-pipe emit path (v1.1-B, pdxwatch#12)
targets SC+ sysno 115 (`sys_semantic_send`). At v1.1-A the caps.decl
forward-declares the schema and its emit transport, but the
userspace emitter is NOT yet scaffolded. The kernel dispatch table
DOES route sysno 115 to `_semantic_ring` at paideia-os HEAD
(sysno 115 landing at R107-M0-001, paideia-os#2350) -- unlike
postui-top's v1.0.0 -ENOSYS caveat, pdxwatch's v1.1-B emit path
lands directly against a live sysno.

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
