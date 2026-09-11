# Changelog

All notable changes to `pdxwatch` are documented here. This project
adheres to a Keep-a-Changelog-style shape: newest version first, one
section per released tag, dated `YYYY-MM-DD`. Categories used:
`Added`, `Changed`, `Fixed`, `Deprecated`, `Removed`, `Security`.

## [Unreleased]

### Added

- **v1.2-A -- M2-001 CPU bar-per-core widget** (pdxwatch#3).
  - `src/widget_cpu.pdx` (new, `module WidgetCpu`): per-online-CPU
    load-bar render widget. Reads `CollectSnapshot.num_cpus` +
    `per_cpu_active[0..8]` and renders one horizontal bar per online
    CPU into a caller-supplied BGRA8888 framebuffer. Bar width scales
    to a load% proxy (per-CPU RUNNING task count * 25, saturating at
    100 at 4 concurrent tasks); color gradient at 50%/80% thresholds
    (green / yellow / red). Labels drawn as a 9-glyph strip via
    `pwc_gfx_draw_glyph`. Fingerprint `pdxwatch cpu-widget ok\n`
    emitted once on first successful render via SC+ sysno 12
    (`sys_debug_puts`).
  - Entry point: `WidgetCpu::cpu_widget_render(fb_ptr, snap_ptr, x0,
    y0, width, height) -> u64`. Extended-arity vs the R102.M2-001
    issue's 5-arg shape: `snap_ptr` is passed explicitly because
    pdxwatch's M1 era has no shared-global snapshot slot. Narrows
    back to the 5-arg shape when M1-002 introduces a widget-registry
    global.
  - MAX_CPUS = 8 (matches Collectors' `PW_MAX_CPUS` -- rendering
    ceiling, not the M1-era hard-coded `num_cpus = 1`).
  - Load% derivation: `min(100, per_cpu_active[i] * 25)` -- the M1-era
    stopgap. The R102.M2-001 issue names the ideal
    `(cpu_ticks * 100) / (cpu_ticks + idle_ticks)` formula; neither
    `idle_ticks` nor per-CPU `cpu_ticks` is surfaced by paideia-os
    HEAD's SC+ layer, so the widget uses per-CPU RUNNING-task count
    as a load proxy. `_pwc_prior_total_cpu_ticks` / `_pwc_prior_
    refresh_count` scratch reserved for the sys_cpuinfo landing.
  - **Inline libpdx-gfx / libpdx-font stubs**: `pwc_gfx_fill_rect`
    (BGRA rect fill using sized `mov_d` 32-bit stores) and
    `pwc_gfx_draw_glyph` (8x8 solid-cell fill stub) are inlined
    here since libpdx-gfx.M2-002 (`gfx_fill_rect`) and libpdx-
    font.M2-001 (`gfx_draw_glyph`) have not landed in the pdxwatch
    link path (nor are either library resident in the paideia-os
    monorepo). Every stub carries a `// STUB(libpdx-*.M2-*)` marker
    at the callsite. A follow-up dependency issue ("pdxwatch: retire
    widget_cpu.pdx libpdx-gfx/font stubs when M2-002 / M2-001 land")
    should be filed against `paideia-os/pdxwatch` when M1-002 opens
    the surface_open wire.
  - Error-band claim extended: `0xFFFFE210..0xFFFFE21F` (widget's
    fault surface: `PWC_ERR_BAD_FB_PTR`, `PWC_ERR_BAD_SNAP_PTR`,
    `PWC_ERR_RECT_TOO_SMALL`); collectors' `0xFFFFE200..0xFFFFE20F`
    holdings unchanged.
  - `src/main.pdx`: adds `_pw_fb : [u8; 98304] @align(64)` .bss
    stub framebuffer (256x96 BGRA, stride 1024 bytes); modifies
    the bounded-iterate loop to call `cpu_widget_render` after
    each `collect_tick` return of 1 (refresh happened). The
    bounded-iterate exit trigger remains `PW_MAIN_TICK_BUDGET`
    iterations, not refresh count.
  - `caps.decl`: `syscalls:` block gains `sys_debug_puts @ 12`
    (WidgetCpu fingerprint emit).
  - `manifest.pdxproj`: `sources:` block promotes
    `src/widget_cpu.pdx` from commented forward-declaration to
    live entry.

### Notes

- The fingerprint `pdxwatch cpu-widget ok` is emitted through
  `sys_debug_puts` (kernel-owned debug channel, bypasses fd
  routing). A boot smoke that runs pdxwatch under QEMU can grep
  the serial console for this string to gate M2-001 "widget wired
  and firing" verification. Emission is one-shot per process
  lifetime (`_pwc_fp_emitted` flag) so the 1Hz refresh loop does
  not spam the console.
- `WidgetCpu::PWC_FB_STRIDE_BYTES = 1024` is hard-coded to match
  the `_pw_fb` stub's row pitch. When gfx_surface_open lands and
  SurfaceHandle carries stride, `cpu_widget_render` gains a
  `stride_bytes` parameter and this constant is deleted.

## [1.1.0] - 2026-09-08

Track-C "real body + semantic-pipe emit" pass. The M1-001 scaffold
that landed on 2026-09-07 as v1.1-A retired the returns-0 stub the
R102.M1-001 issue text originally named, and landed the real
syscall aggregation path directly. v1.1-B then wired the
`SysStatRecord@0.1` producer emit through the newly-live SC+ sysno
115 (`sys_semantic_send`) inside the same collector module. v1.1-C
(this release) closes the wave with the version bump + tag.

### Added

- **v1.1-A — real-body extraction** (pdxwatch#11).
  - `src/collectors.pdx` (`module Collectors`): `CollectSnapshot`
    struct + `collect_init` + `collect_tick`. Wires SC+ sysno 83
    (`sys_taskinfo`) + sysno 66 (`sys_clock_read_ns`) into a
    fixed-tick aggregate -- total CPU-ticks, total RSS in KiB,
    per-state task counts, per-CPU active-task buckets. Same
    syscall pair `postui-top`'s poll module uses; both consumers
    share the KIND_SYS_STAT-less client-side aggregation posture
    `r102-user-plan.md` §2.8 flagged.
  - `src/main.pdx` (`module Main`): `Main::main` dispatch entry.
    Runs `collect_init(&_pw_snapshot, PW_MAIN_INTERVAL_TICKS=60)`
    then a bounded 32-iterate loop over `collect_tick`, then
    `sys_exit(0)`. Bounded shape is deliberately witness-testable;
    M3-001's `q` keydown will replace it with an unbounded loop.
  - `caps.decl`: `KIND_SURFACE(mint,commit,revoke)` +
    `KIND_IPC_ENDPOINT(subscribe)` + `KIND_MEMORY(mint,revoke)`
    forward declarations. `syscalls:` block declares sysno 66 +
    sysno 83. `declares_output_schemas:` forward-declares
    `SysStatRecord@0.1` for the v1.1-B emitter.
  - `manifest.pdxproj`: kind = tool, entry = `Main::main`
    (forward-declared until M1-005), `sources:` block seeds
    `src/collectors.pdx` + `src/main.pdx`, `deps:` block declares
    `libpdx-gfx` / `libpdx-event` / `libpdx-font` at `^0.1`,
    `compliance:` block enumerates the six paideia-as invariants
    (module-basename-pascal, no-test-mnemonic, cmp-imm32-only,
    r11-scratch, byte-load-zero-then-mov_b, sysv-push-pop-parity).
  - `tools/build.sh`: per-repo build script mirroring
    `postui-top`'s shape. Compiles `src/*.pdx` + `tests/*.pdx`
    into loose ELF64 objects under `build-out/` via
    `paideia-as build --emit elf64`. Requires paideia-as
    `>= 0.36.0` (encoder floor for the mnemonic surface this
    landing exercises).
  - Error-band claim: `0xFFFFE200..0xFFFFE20F` (headroom reserved
    to `0xFFFFE2FF` for M1-002+ growth).
- **v1.1-B — semantic-pipe emit wire** (pdxwatch#12).
  - `src/collectors.pdx` gains:
    - `pw_sys_semantic_send(schema, record_ptr, record_len)`
      wrapper for SC+ sysno 115. Kernel body at paideia-os
      `src/kernel/core/syscall/handlers/sys_semantic_send.pdx`
      (R107-M0-001 landing, paideia-os#2350) is live at HEAD.
    - `PW_SEMANTIC_SCHEMA_SSTA = 0x41545353` schema tag (4-char
      ASCII `'SSTA'` little-endian, per postui
      `SEMANTIC_SCHEMA_<TAG>` convention; transitional until
      libpdx-semantic-pipe's BLAKE3-hash schema registry lands).
    - `PW_SEMANTIC_RECORD_OFF = 32` and
      `PW_SEMANTIC_RECORD_BYTES = 160` constants naming the wire
      slice.
    - `PW_SNAP_OFF_SEMANTIC_EMIT_OK = 192` and
      `PW_SNAP_OFF_SEMANTIC_EMIT_FAIL = 200` observability
      counters inside the `CollectSnapshot` reserved region.
    - `PW_ERR_EMIT_EFAULT` / `PW_ERR_EMIT_EINVAL` sentinel
      reservations within the pdxwatch error band (unused at
      v1.1-B; reserved for a future round that surfaces emit
      errors up through the M2 render path).
    - Phase D-bis emit block in `collect_tick` between the
      aggregate-commit (Phase D) and the tick-anchor (Phase E).
      Emitted record is the 160-byte contiguous slice
      `[state_ptr + 32 .. state_ptr + 192)` -- byte-for-byte
      prefix of the `CollectSnapshot` fields the schema names, so
      no marshalling buffer is needed. On `rax == 0` the
      emit_ok counter increments; on `rax != 0` the emit_fail
      counter increments; the tick still commits either way
      (best-effort emit).

### Changed

- **v1.1-B** — `caps.decl` `SysStatRecord@0.1` field enumeration
  tightened to match the wire (`task_seen` + `task_skipped` added;
  total 160B; the earlier "144B" figure was an off-by-N in the
  v1.1-A forward-declaration). `syscalls:` block gains
  `sys_semantic_send @ 115`.
- **v1.1-C** — `manifest.pdxproj` `version` bumped from `1.0.0`
  (M5-001 forward-declaration placeholder) to `1.1.0` to match
  this release.

### Removed

- **v1.1-A** — R102.M1-001's returns-0 stub concept. The scaffold
  and the real syscall body land together as one round; there is
  no intermediate stub commit to retire later.
- **v1.1-B** — `manifest.pdxproj`'s speculative
  `# - src/semantic_emit.pdx` forward-declaration. The emit path
  lives inside `src/collectors.pdx` (single caller, no reuse
  surface -- extracting would fragment the round without benefit).

### Notes

- Fingerprint: pdxwatch's console/render surface is unchanged
  across v1.1-A + v1.1-B. The semantic pipe is an out-of-band
  structured emit channel; no duplicate write of any terminal /
  KIND_SURFACE payload.
- `libpdx-gfx` / `libpdx-event` / `libpdx-font` dependencies are
  declared in `manifest.pdxproj` but not linked at v1.1.0 --
  pdxwatch's Track-C surface is pure userspace with two
  `sys_taskinfo` + `sys_clock_read_ns` wrappers plus the sysno
  115 semantic emit. M1-002+ landings will wire the graphical
  stack in as those libraries reach M1..M3.

### Post-v1.1.0 roadmap

- M1-005: `_start` binder + `Main::main` call frame; produces a
  linkable ELF at `build-out/pdxwatch`.
- M2 wave: CPU / mem / net widgets against libpdx-gfx M2.
- M3-001: libpdx-event M3 wire-in (click-cycle + `q` quit).
- M4 witness triplet: seeded-stat, click-cycle, keyboard-quit.
- M5-001: signed 1.0.0 release closer. (Note: the semantic v1.0.0
  release closer remains a future M5 milestone; the 1.1.0 tag
  here reflects the Track-C real-body + semantic-pipe wave
  landing ahead of the graphical-stack completion.)
