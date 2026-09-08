# pdxwatch

System-monitor GUI — the **graphical peer of `postui-top`**. Reads
the same live-system surface `postui-top` reads (SC+ sysno 83
`sys_taskinfo`, aggregated client-side into a per-CPU / memory /
task-state snapshot), renders CPU/memory/network as bar-graph and
sparkline widgets. 480x360 window, 1 Hz refresh, per-widget damage
tracking.

Part of the **paideia-os** organization. MIT-licensed.

## Status

**M1-001 real body landed 2026-09-07 (v1.1-A, pdxwatch#11).** The
scaffold + real syscall path landed together -- the R102.M1-001
stub-body concept was retired in favor of a single real-body
landing (see `STATUS.md` and `src/collectors.pdx` §V1.1-A "RETIRE
THE STUB BODY" LANDING).

The window-creation, widget-render, and input-handling milestones
(M1-002 through M3-001) are blocked on `libpdx-gfx` and
`libpdx-event` M1..M3 landings and remain pending.

## Wave

R102 (softarch userland graphical stack) — the CPU-side framebuffer
stack that lands the first graphical UI on paideia-os before the
G-series GPU-accelerated compositor matures. Companion to the
osarch R101 kernel-side plan.

## Design reference

- Design lives in the monorepo at [`design/graphics/r102-user-plan.md`](https://github.com/paideia-os/paideia-os/blob/main/design/graphics/r102-user-plan.md) §2.8 / §4.8.
- Kernel-side companion: `design/graphics/r101-kernel-plan.md`.

## Milestones

Per the plan, this repo lands across five milestones plus the
Track-C v1.1 pass:

- **M1-001** — CollectSnapshot + `sys_taskinfo` aggregation
  collectors + Main::main dispatch loop. **landed (v1.1-A)**
- **M1-002** — caps.decl window opening + 480x360 KIND_SURFACE +
  argv parser. pending libpdx-gfx M1
- **M2** — CPU bar-per-core / memory tri-color / network sparkline
  widgets; 1 Hz refresh; per-widget damage. pending libpdx-gfx M2
- **M3** — click-to-cycle-detail per CPU bar; `q` to quit.
  pending libpdx-event M3
- **M4** — smokes: seeded-stat render, click-cycle, keyboard quit
- **M5** — signed 1.0.0 release
- **v1.1-B** — `SysStatRecord@0.1` semantic-pipe emission wire
  (pdxwatch#12)
- **v1.1-C** — release closer v1.1.0 + tag (pdxwatch#13)

Every issue is filed against one of these milestones; see the
Issues tab.

## Data source

`sys_taskinfo` (SC+ sysno 83, frozen at R57.M4-003 + R60.M7-002 in
paideia-os), polled on a fixed 16.7ms-per-"tick" interval driven
by `sys_clock_read_ns` (SC+ sysno 66). See `src/collectors.pdx`
§Tick semantics for the ns-to-tick conversion rationale (same
2^24-ns = 16.7ms convention `postui-top`'s poll module uses --
both consumers share the KIND_SYS_STAT-less "read the task_pool
directly and aggregate client-side" posture flagged in
`r102-user-plan.md` §2.8).

The M1-001 collector aggregates each task_pool sweep into:

- `total_cpu_ticks` -- sum of every task's 100 Hz LAPIC ticks
- `total_rss_kb` -- sum of `rss_pages << 2`
- `task_state_counts[NEW..EXITED]` -- per-state bucketing
- `per_cpu_active[0..8]` -- round-robin bucketed active-task counts
  (num_cpus hard-coded to 1 at M1-001; `sys_cpuinfo` landing at
  M2 will widen the bucketing to real CPU affinity)
- `task_seen` / `task_skipped` -- successful vs skipped
  (ENOENT/ESRCH/EFAULT) slot counts

## Layout

    manifest.pdxproj            # paideia-as build manifest (kind = tool)
    caps.decl                   # KIND_SURFACE + KIND_IPC_ENDPOINT + KIND_MEMORY
                                # requires; SysStatRecord@0.1 forward-declared
    tools/build.sh              # per-repo build script (mirrors postui-top's)
    src/collectors.pdx          # M1-001: CollectSnapshot + collect_init + collect_tick
    src/main.pdx                # M1-001: Main::main dispatch loop + pw_sys_exit

## Build

    bash tools/build.sh

Compiles every source under `src/` into loose ELF64 objects under
`build-out/`. Requires `paideia-as >= 0.36.0` (the version-floor
check refuses fast otherwise).

## Run

At M1-001 the downstream link + boot into a live paideia-os target
is DEFERRED to M1-005 (`_start` binder + `Main::main` call frame);
`bash tools/build.sh` produces the loose-object set only. Once
linked and launched as `/bin/pdxwatch`, the program opens a 480x360
KIND_SURFACE (M1-002), aggregates `sys_taskinfo` on a 1 Hz refresh,
and renders the CPU / memory / network widgets (M2). Click a CPU
bar to cycle its detail mode (M3); press `q` to exit (M3).

## Release

Dual-signed tarball (`pdxwatch-v1.0.0.tar.gz`) per the `release:`
block in `manifest.pdxproj`:

- Primary: ML-DSA-65 (post-quantum), signer
  `snunez+pdxwatch-author@paideia-os.dev`.
- Secondary: Ed25519 (classical), root signer
  `paideia-os-release-root@paideia-os.dev`.
- Mirror target: `pkgs.paideia-os`.

`pkg install pdxwatch` requires BOTH signatures to verify.

## License

MIT — see [LICENSE](LICENSE).
