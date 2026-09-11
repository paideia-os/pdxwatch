# Changelog

All notable changes to `pdxwatch` are documented here. This project
adheres to a Keep-a-Changelog-style shape: newest version first, one
section per released tag, dated `YYYY-MM-DD`. Categories used:
`Added`, `Changed`, `Fixed`, `Deprecated`, `Removed`, `Security`.

## [Unreleased]

### Added

- **v1.4-A -- M4-001 seeded-stat render smoke** (pdxwatch#7).
  - `tests/test_seeded_stat_smoke.pdx` (new, `module TestSeededStatSmoke`):
    boot-smoke witness for the M2 widget stack (CPU / mem / net).
    Bypasses the real `sys_taskinfo` aggregation path, seeds a
    private `CollectSnapshot` .bss slot with known fixture values
    (4 CPUs at 50% via `per_cpu_active[0..4]=2`, 8 GiB used via
    `total_rss_kb=8388608`, network activity proxy via
    `task_seen=15`), drives `cpu_widget_render`, `mem_widget_render`,
    `net_widget_render` in turn against a private 256x128 BGRA
    back-buffer, computes per-widget sum-of-qwords digests over
    CPU rows `[0..79]`, mem rows `[84..93]`, net rows `[96..127]`,
    compares to hardcoded expected constants, and emits the
    serial-console fingerprint `pdxwatch seeded-stat ok\n` (24 bytes)
    via SC+ sysno 12 sys_debug_puts on all-pass. Fail-code band
    `0xFFFFE2F0..0xFFFFE2F5` per the M4-001 reservation in
    `manifest.pdxproj`:
    - `SSS_FAIL_CPU_DIGEST` / `SSS_FAIL_MEM_DIGEST` /
      `SSS_FAIL_NET_DIGEST` (0xFFFFE2F0..0xFFFFE2F2) -- per-widget
      digest mismatch.
    - `SSS_FAIL_CPU_RENDER_ERR` / `SSS_FAIL_MEM_RENDER_ERR` /
      `SSS_FAIL_NET_RENDER_ERR` (0xFFFFE2F3..0xFFFFE2F5) -- widget
      render entry returned a non-zero refuse code (arg validation:
      bad fb/snap pointer or too-small rect).
  - Six `pub let` entries:
    - `sss_sys_debug_puts(buf, count)` -- thin SC+ sysno 12 wrapper,
      byte-for-byte replica of the peer widget wrappers.
    - `sss_seed_snapshot(state_ptr)` -- zero-fills 256 bytes then
      stamps interval_ticks=60, num_cpus=4, per_cpu_active[0..4]=2,
      total_rss_kb=8388608, task_seen=15 (offsets 0, 24, 32..56,
      104, 176 respectively -- mirror `src/collectors.pdx`
      `PW_SNAP_OFF_*`).
    - `sss_digest_subrect(fb_ptr, y_start, y_count)` -- sum-of-qwords
      fold over the rectangle rows `[y_start .. y_start + y_count)`,
      full 1024-byte row stride (128 qwords/row). Chosen over
      sum-of-bytes because the paideia-as encoder's `mov_b` byte-load
      form is documented but unexercised anywhere in the pdxwatch
      tree; qword loads through `mov rax, [reg + reg]` are exercised
      at every widget callsite and semantically equivalent for the
      smoke's deterministic-digest requirement.
    - `sss_emit_fingerprint()` -- one-shot serial-console emit of
      `pdxwatch seeded-stat ok\n` via three qword stores +
      `_sss_fp_emitted` gate; matches the widget fingerprint pattern
      shared across the M2 landings.
    - `seeded_stat_smoke()` -- boot-smoke witness orchestrator:
      seed, render(cpu/mem/net), digest(cpu/mem/net), verify, emit.
      No fingerprint on any fail path -- silent console is the
      catches-the-placeholder-not-yet-frozen observable.
  - **Placeholder-fingerprint policy**: `SSS_EXPECTED_CPU_DIGEST` /
    `SSS_EXPECTED_MEM_DIGEST` / `SSS_EXPECTED_NET_DIGEST` are seeded
    at `0xFFFFFFFFFFFFFFFF` -- unreachable for a sum-of-qwords fold
    over the widget sub-rect volumes (max real digest ~21M). The
    placeholder ALWAYS mismatches the actual computed digest on the
    first green build, so the smoke returns a `0xFFFFE2Fx` sentinel
    on the first run and DOES NOT emit the `pdxwatch seeded-stat ok`
    fingerprint until the expected constants are frozen. The
    freeze-after-first-green procedure is documented in the source
    file's §PLACEHOLDER-FINGERPRINT POLICY.
  - `manifest.pdxproj` `tests:` block gains the new entry as the
    first item (M4-001 lands ahead of the already-listed M4-002 /
    M4-003 entries per the tests-band numeric ordering). The
    forward-declaration comment ("KIND_SYS_STAT seeding primitive")
    is rewritten to note the syscall-bypass resolution.

- **v1.3-A -- M3-001 click-cycle detail-toggle + 'q'-quit dispatch**
  (pdxwatch#6).
  - `src/input.pdx` (new, `module Input`): input-event dispatch
    surface for the M3 landing. Four `pub let` entries:
    - `pwi_sys_debug_puts(buf, count)` -- thin SC+ sysno 12 wrapper,
      identical shape to WidgetCpu's / WidgetMem's / WidgetNet's peer
      wrappers.
    - `pwi_emit_fingerprint()` -- one-shot serial-console emit of
      `pdxwatch input ok\n` (18 bytes) via three qword stores +
      `_pwi_fp_emitted` gate; matches the widget fingerprint pattern
      shared across the M2 landings.
    - `input_dispatch_pointer(y)` -- resolves a screen-space y-coord
      to a CPU-bar index (`cpu_idx = y / 10` via a subtract-and-count
      loop; no `imul` / `div`) and calls `cpu_widget_toggle_detail`
      to flip the per-bar detail flag. y >= 80 (outside the CPU
      widget rect) is silently ignored; mem/net widget click
      handlers are deferred to a future round.
    - `input_dispatch_key(keycode)` -- if keycode == 'q' (0x71),
      calls `pw_request_quit` to raise the Main-owned quit flag;
      other keycodes fall through without touching the flag
      (matches the M4-003 `pqs_state_key` contract at
      tests/test_q_quit_smoke.pdx#9).
    - `input_poll_events()` -- **STUB(libpdx-event.M3-001)**: real
      event_next queue drain pending the libpdx-event M3 landing.
      At stub, returns 0 (no events dispatched) unconditionally.
      Marker `STUB(libpdx-event.M3-001)` at the source callsite
      audit-trails the wire-up point. Follow-up dependency issue
      ("pdxwatch: retire input.pdx event-queue stub when libpdx-
      event.M3-001 lands") should be filed against
      paideia-os/pdxwatch when the library reaches M3.
  - `src/widget_cpu.pdx`:
    - New `_pwc_detail : [u64; 8]` .bss slot -- per-CPU-bar detail
      flag (0 = compact, 1 = expanded). Deviation from the issue
      text's `[u8; 8]` shape documented at §Detail-mode constants:
      the u64-per-bar stride matches the sibling M4-002 test
      fixture (`modes[0..8] : u64 x 8`) and dodges the paideia-as
      byte-store encoder pitfall uniformly.
    - New `cpu_widget_toggle_detail(cpu_idx)` accessor: bounds-
      checks `cpu_idx < 8`, then `xor rax, 1` on the u64 slot.
      Called from `Input::input_dispatch_pointer` on every CPU-bar
      click.
    - New `PWC_DETAIL_COMPACT` / `PWC_DETAIL_EXPANDED` /
      `PWC_COLOR_USER` (green, `0xFF20C020`) / `PWC_COLOR_KERNEL`
      (magenta, `0xFFA050D0`) constants.
    - `cpu_widget_render` Phase D.4 (bar draw): now branches on
      `_pwc_detail[cpu_idx]`. Compact = single 8-px bar with the
      load-gradient color (unchanged). Expanded = two stacked
      sub-bars, top 4-px user (green) + bottom 4-px kernel
      (magenta), each at `bar_fill_w/2` width. Both sub-bars share
      the M3-era proxy `user_pct = kernel_pct = active_pct/2`
      until sys_cpuinfo lands and the split becomes real; the
      sub-bar rendering shape (top user / bottom kernel, four
      pixels each, half-fill each) does not change under the
      sys_cpuinfo landing.
  - `src/main.pdx`:
    - New `_pw_quit_requested : [u64; 1]` .bss slot -- quit-request
      flag polled at the tail of every dispatch-loop iteration.
    - New `pw_request_quit()` accessor: sets `_pw_quit_requested`
      to 1. Idempotent under repeated calls. Called from
      `Input::input_dispatch_key` on ASCII 'q' keydown.
    - `Main::main` dispatch loop tail: calls `input_poll_events`
      on every iteration (not just refresh iterations), then reads
      `_pw_quit_requested`; a non-zero value jumps to the clean-
      exit phase (`pw_sys_exit(0)`). While the M3-001 stub returns
      0 events, the quit flag stays 0 and the bounded budget
      (`PW_MAIN_TICK_BUDGET = 32`) remains the terminal exit
      trigger; when libpdx-event.M3-001 lands and the stub is
      retired, the loop terminates on the first 'q' keydown.
      Shutdown path: the existing `pw_sys_exit(0)` tail-call is
      the sole cleanup step -- no explicit fb free (backing store
      is .bss, reclaimed on process teardown by the kernel), no
      surface teardown (KIND_SURFACE not minted until M1-002).
      A closing serial fingerprint on quit is deferred to a
      future round that wires surface revoke + explicit cleanup.
  - `manifest.pdxproj`: `sources:` block promotes `src/input.pdx`
    from commented forward-declaration to live entry.
  - `caps.decl`: no change at this landing. The follow-up
    libpdx-event.M3-001 wire-in will add `sys_ipc_recv @ 40`
    when the queue-drain body materializes; `sys_debug_puts @ 12`
    (already declared for the M2 widget fingerprints) covers the
    `pdxwatch input ok` emit shared by the two dispatch entries.
  - Closes #6.

- **v1.2-C -- M2-003 network sparkline widget** (pdxwatch#5).
  - `src/widget_net.pdx` (new, `module WidgetNet`): per-interface
    bytes/s sparkline render widget. Maintains a fixed-size circular
    ring of the last 60 samples per interface (`_pwn_ring`,
    MAX_NIFS=4 * RING_LEN=60 * 8 bytes = 1920 bytes; iface 0 populated
    at v1.2-C, other slots reserved for a real multi-iface
    `sys_netinfo` landing). At 1 Hz refresh cadence 60 samples cover
    ~1 min of history. Renders as a label strip (9 glyph cells at
    row `y0`) + a baseline track row + 59 connected line segments
    across the 60-sample ring, all painted into a caller-supplied
    BGRA8888 framebuffer. Fingerprint `pdxwatch net-widget ok\n`
    emitted once on first successful render via SC+ sysno 12
    (`sys_debug_puts`).
  - Entry point: `WidgetNet::net_widget_render(fb_ptr, snap_ptr,
    x0, y0, width, height) -> u64`. Extended-arity vs the R102.M2-003
    issue's 5-arg shape: `snap_ptr` passed explicitly for the same
    M1-era reason peer widgets use. All three signatures narrow back
    to 5 args together when M1-002 introduces a widget-registry
    global.
  - Net-stat source (M1-era proxy; no `sys_netinfo` on paideia-os
    HEAD -- verified via grep of `design/user/syscall-table.md` and
    the socket band 86..103 which surfaces no per-interface byte
    counter): `sample = task_seen - prior_task_seen` (unsigned wrap
    OK; `_pwn_prior_task_seen` carries the previous-tick value in
    widget-owned .bss scratch). Sample is intentionally left in
    task-delta units rather than pre-scaled to KB/s -- task_seen is
    bounded by PW_MAX_TASKS=64 so `min(sparkline_h - 1, sample)`
    clamp gives exact per-pixel resolution without a runtime
    multiply. Retires without shape churn when
    sys_netinfo / KIND_NET_STAT-invoke lands.
  - Ring buffer semantics: `_pwn_ring_head` names the NEXT-INSERT
    slot; iterating head..head+59 mod RING_LEN yields oldest-first
    in temporal order (sparkline draws left-to-right).
    `_pwn_ring[iface][slot]` at byte offset `(iface * 60 + slot) * 8`;
    per-iface stride 480 (non-power-of-two but iface 0 = offset 0 at
    v1.2-C so no runtime multiply needed).
  - Color scheme (cyan sparkline over dark charcoal, distinct from
    WidgetCpu's green/yellow/red warning gradient and WidgetMem's
    dark-to-light blue ramp so users parse the three stacked widgets
    as three independent quantities):
      - `PWN_COLOR_SPARK = 0xFF00C0C0` cyan (sparkline segments)
      - `PWN_COLOR_TRACK = 0xFF404040` medium charcoal (baseline)
      - `PWN_COLOR_BG` and `PWN_COLOR_LABEL` match peer widgets.
  - **Inline libpdx-gfx / libpdx-font stubs** (`pwn_gfx_fill_rect`,
    `pwn_gfx_draw_glyph`): byte-for-byte replicas of WidgetCpu's /
    WidgetMem's stubs, prefixed `pwn_*` so a future wire-up round
    does not collide on link. New this round: `pwn_gfx_draw_line`
    (staircase step-chart shape -- horizontal fill_rect from
    (x0, y0) to (x1, y0) plus a vertical fill_rect at x1 spanning
    [min(y0,y1)..max(y0,y1)]) marks `// STUB(libpdx-gfx.M2-003)`.
    All three widget stubs retire together when libpdx-gfx.M2-002
    (`gfx_fill_rect`) + libpdx-gfx.M2-003 (`gfx_draw_line`) +
    libpdx-font.M2-001 (`gfx_draw_glyph`) land. The follow-up
    dependency issue ("pdxwatch: retire widget_cpu.pdx /
    widget_mem.pdx / widget_net.pdx libpdx-gfx + libpdx-font stubs")
    now covers all three widgets together.
  - Error-band claim extended: `0xFFFFE230..0xFFFFE23F` (widget's
    fault surface: `PWN_ERR_BAD_FB_PTR`, `PWN_ERR_BAD_SNAP_PTR`,
    `PWN_ERR_RECT_TOO_SMALL`); Collectors', WidgetCpu's, and
    WidgetMem's earlier holdings unchanged.
  - `src/main.pdx`: bounded-iterate loop now calls
    `net_widget_render` right after `mem_widget_render` on every
    refresh return of 1. `_pw_fb` grows from `[u8; 98304]`
    (256x96 rows) to `[u8; 131072]` (256x128 rows) to accommodate
    the net widget at (x0=0, y0=96, w=256, h=32). Peer widgets'
    geometry unchanged; rows 94..95 remain visual gap between the
    mem bar and the sparkline. Updated row-map table lives in
    main.pdx's `_pw_fb` comment.
  - `caps.decl`: `sys_debug_puts @ 12` note extended to record
    the WidgetNet fingerprint emitter shares the syscall (no new
    entry needed; kernel dispatch is idempotent across all three
    widgets' one-shot emits).
  - `manifest.pdxproj`: `sources:` block promotes
    `src/widget_net.pdx` from commented forward-declaration to
    live entry.
  - Closes #5.

- **v1.2-B -- M2-002 memory tri-color widget** (pdxwatch#4).
  - `src/widget_mem.pdx` (new, `module WidgetMem`): tri-color memory
    bar render widget. Reads `CollectSnapshot.total_rss_kb` (offset
    +104, already populated by Collectors::collect_tick) and
    `CollectSnapshot.task_seen` (offset +176) and renders one
    horizontal bar with three subrects (used / cached / free) into
    a caller-supplied BGRA8888 framebuffer. Segment widths scale
    from KiB to pixels via a single `shr reg, 11` (2048 KiB per
    pixel; encoder-safe, no imul, no div). Labels drawn as a
    9-glyph strip via `pwm_gfx_draw_glyph`. Fingerprint
    `pdxwatch mem-widget ok\n` emitted once on first successful
    render via SC+ sysno 12 (`sys_debug_puts`).
  - Entry point: `WidgetMem::mem_widget_render(fb_ptr, snap_ptr,
    x0, y0, width, height) -> u64`. Extended-arity vs the
    R102.M2-002 issue's 5-arg shape: `snap_ptr` is passed
    explicitly for the same M1-era reason WidgetCpu's entry point
    uses. Both signatures narrow back to 5 args together when
    M1-002 introduces a widget-registry global.
  - Memory-stat source (M1-era proxy; no `sys_meminfo` on paideia-
    os HEAD -- verified via grep against `design/user/syscall-
    table.md` and `src/kernel/`):
      - `used_kb = total_rss_kb`  (Collectors' RSS aggregate --
        the field the CollectSnapshot layout comment explicitly
        reserved "for the M2 memory tri-color widget").
      - `cached_kb = task_seen << 4`  (proxy: 16 KiB "cached"
        per live task; bounded because `task_seen <= 64` so
        `cached_kb <= 1024`. Retires when a real page-cache
        counter lands via sys_meminfo / KIND_PMM-invoke).
      - `free_kb = PWM_MEM_TOTAL_KB - used_kb - cached_kb`
        (assumed 256 MiB pool matches QEMU `-m 256`; swapped
        for a live sys_meminfo read when that syscall lands).
    `_pwm_prior_total_rss_kb` scratch reserved for the sys_meminfo
    landing's memory-pressure delta computation; unused at M2-002.
  - Color scheme (monochromatic dark-to-light BLUE ramp, distinct
    from WidgetCpu's warning gradient so users parse the mem bar
    as one quantity subdivided into three parts, not three
    independent alerts):
      - `PWM_COLOR_USED   = 0xFFB03018`  dark ocean blue
      - `PWM_COLOR_CACHED = 0xFFD07040`  medium blue
      - `PWM_COLOR_FREE   = 0xFFE0B080`  light sky blue
      - `PWM_COLOR_BG` and `PWM_COLOR_LABEL` match WidgetCpu.
  - **Inline libpdx-gfx / libpdx-font stubs** (`pwm_gfx_fill_rect`,
    `pwm_gfx_draw_glyph`): byte-for-byte replicas of WidgetCpu's
    `pwc_gfx_*` stubs, prefixed `pwm_*` so a future wire-up round
    does not collide on link. Retired together when
    libpdx-gfx.M2-002 (`gfx_fill_rect`) and libpdx-font.M2-001
    (`gfx_draw_glyph`) land. The follow-up dependency issue
    ("pdxwatch: retire widget_cpu.pdx / widget_mem.pdx libpdx-gfx
    + libpdx-font stubs when M2-002 / M2-001 land") covers both
    widgets together.
  - Error-band claim extended: `0xFFFFE220..0xFFFFE22F` (widget's
    fault surface: `PWM_ERR_BAD_FB_PTR`, `PWM_ERR_BAD_SNAP_PTR`,
    `PWM_ERR_RECT_TOO_SMALL`); WidgetCpu's
    `0xFFFFE210..0xFFFFE21F` and Collectors' `0xFFFFE200..0xFFFFE20F`
    holdings unchanged.
  - `src/main.pdx`: the bounded-iterate loop now calls
    `mem_widget_render` right after `cpu_widget_render` on every
    refresh return of 1. CPU widget shrinks from height=96 to
    height=80 (its actual 8-CPU * 10-px row footprint) and the
    memory widget takes the remaining rows at (x0=0, y0=84,
    w=256, h=10) inside the same `_pw_fb` back-buffer -- rows
    80..83 stay as background gap between the two widgets. No
    `_pw_fb` resize needed.
  - `caps.decl`: `sys_debug_puts @ 12` note extended to record
    the WidgetMem fingerprint emitter shares the syscall (no
    new entry needed; kernel dispatch is idempotent).
  - `manifest.pdxproj`: `sources:` block promotes
    `src/widget_mem.pdx` from commented forward-declaration to
    live entry.

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
  not spam the console. The v1.2-B `pdxwatch mem-widget ok`
  fingerprint uses the identical shape (one-shot via
  `_pwm_fp_emitted`), so a boot smoke can grep both strings to
  gate the two M2 landings independently.
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
