# pdxwatch

System-monitor GUI — the **graphical peer of `postui-top`**. Reads the same live-system query surface `postui-top` reads (via semantic-pipe), renders CPU/memory/network as bar-graph and sparkline widgets. 480x360 window, 1 Hz refresh, per-widget damage tracking.

Part of the **paideia-os** organization. MIT-licensed.

## Wave

R102 (softarch userland graphical stack) — the CPU-side framebuffer stack
that lands the first graphical UI on paideia-os before the G-series
GPU-accelerated compositor matures. Companion to the osarch R101 kernel-side
plan.

## Design reference

- Design lives in the monorepo at [`design/graphics/r102-user-plan.md`](https://github.com/paideia-os/paideia-os/blob/main/design/graphics/r102-user-plan.md) §2.8 / §4.8.
- Kernel-side companion: `design/graphics/r101-kernel-plan.md`.

## Milestones

Per the plan, this repo lands across five milestones:

- **M1** — repo scaffold; caps.decl (KIND_SURFACE, libpdx-event, KIND_SYS_STAT); argv parser; 480x360 window; placeholder widget layout
- **M2** — CPU bar-per-core widget; memory tri-color widget; network sparkline widget (last-60 ring); 1 Hz refresh; per-widget damage
- **M3** — click-to-cycle-detail per CPU bar; 'q' to quit
- **M4** — smokes: seeded-stat render, click-cycle, keyboard quit
- **M5** — signed 1.0.0 release

Every issue is filed against one of these five milestones; see the Issues tab.

## Scaffolding

No code lands with this repo scaffold — scaffolding lives in the M1
issues (`caps.decl`, `src/` skeleton, public API stubs, argv parsing).
Repo shape mirrors R100 satellites: paideia-as manifest at root,
`caps.decl` at root, `src/` module tree, `tests/`, `release/`,
`doc/<name>.pdxdoc`, dual-signed `manifest.pdxsig` at 1.0.0.

## License

MIT. See [LICENSE](LICENSE).
