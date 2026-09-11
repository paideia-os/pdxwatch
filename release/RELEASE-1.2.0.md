# pdxwatch v1.2.0 — signed release closer (M5-001)

**Repo:** github.com/paideia-os/pdxwatch
**Wave:** R102 userland graphical stack — reference apps
**Version at this release:** 1.2.0 (M5-001 signed-release milestone;
see §1 for the version-name reconciliation)
**Milestone:** R102.M5-001 (pdxwatch#10)
**Upstream policy:** `design/graphics/r102-user-plan.md` §4.8
(paideia-os monorepo) — R102 satellite release policy;
`design/02-development-environment.md` §1140 + §1164 (paideia-os) —
hybrid Ed25519 + ML-DSA-65 signing, release-line key custody;
`design/tooling/plan.md` §6.3 (paideia-os) — package repository
layout.

This document is both the **release note** for what v1.2.0 ships and
the operator runbook for cutting the signed release + pushing it to
`https://pkgs.paideia-os/main/pdxwatch/1.2.0/`. The workflow mirrors
`libpdx-volume`'s `release/RELEASE-1.0.0.md` (this org's other R53-era
satellite through M5) — see that file for the worked template.

The actual `git tag v1.2.0` + mirror push is a **manual step main
performs separately from this milestone** — see §6. This document
describes exactly what that tag would contain so a future operator (or
main, later) can cut it without re-deriving scope from STATUS.md and
five milestones of design-doc flags.

---

## 1. Version-name reconciliation (why v1.2.0, not v1.0.0)

The R102.M5-001 issue body (`gh issue view 10 --repo paideia-os/
pdxwatch`) names "1.0.0" as the signed-release target and reserves
the fingerprint identity `pdxwatch 1.0.0 signed ok`. The pdxwatch
semver line, however, advanced past 1.0.0 before the M5-001 release
closer landed:

- **v1.1.0** — Track-C real-body + semantic-pipe wave (pdxwatch#11 /
  #12 / #13). The v1.1-C release closer (issue #13) bumped
  `manifest.pdxproj` from the M5-001 forward-declaration placeholder
  `1.0.0` to the actual Track-C release `1.1.0` and tagged it, ahead
  of the graphical-stack completion the M5-001 milestone name
  originally anticipated.
- **v1.2.0** (this release) — closes the M4 witness triplet
  (pdxwatch#7 / #8 / #9) plus the M5-001 signed-release wire-up.

Semver monotonicity wins over milestone name: this release tags
**v1.2.0**, not v1.0.0. The fingerprint identity `pdxwatch 1.0.0
signed ok` remains verbatim per the issue's spec — the string names
the M5-001 witness identity (the milestone that first crosses the
dual-signed-release threshold), not the current version number. A
future v2.0.0 would rename the fingerprint identity if the milestone
name is superseded; v1.2.0 preserves it.

---

## 2. What v1.2.0 ships

Everything landed at M1..M4 (see `CHANGELOG.md` for the itemised
per-round list; `STATUS.md` for the per-issue checklist):

- **M1-005 scaffold + collectors** (`src/main.pdx`,
  `src/collectors.pdx`) — real `sys_taskinfo` (sysno 83) +
  `sys_clock_read_ns` (sysno 66) aggregation into an in-memory
  `CollectSnapshot`; `Main::main` dispatch loop with bounded 32-tick
  iterate + `sys_exit(0)` shutdown. Track-C leapfrog of the
  R102.M1-001 returns-0 stub (see v1.1-A landing in CHANGELOG).
- **M2-001 CPU bar-per-core widget** (`src/widget_cpu.pdx`,
  pdxwatch#3) — per-online-CPU load-bar render into a BGRA8888
  back-buffer, warning gradient at 50 / 80 %. Fingerprint
  `pdxwatch cpu-widget ok`.
- **M2-002 memory tri-color widget** (`src/widget_mem.pdx`,
  pdxwatch#4) — used / cached / free segments on a dark-to-light blue
  ramp. Fingerprint `pdxwatch mem-widget ok`.
- **M2-003 network sparkline widget** (`src/widget_net.pdx`,
  pdxwatch#5) — 60-sample circular ring, cyan staircase over dark
  charcoal baseline. Fingerprint `pdxwatch net-widget ok`.
- **M3-001 click-cycle + `q`-quit input dispatch**
  (`src/input.pdx`, pdxwatch#6) — pointer / keydown event dispatch;
  `Input::input_poll_events` is the wired-in libpdx-event.M3
  substrate wire-in point (stubbed at this landing pending
  libpdx-event M3 — see §3 S2 and pdxwatch follow-up).
- **v1.1-B semantic-pipe emit wire** (pdxwatch#12) —
  `SysStatRecord@0.1` producer path through `sys_semantic_send`
  (sysno 115); the byte-for-byte 160-byte prefix of
  `CollectSnapshot[+32..+192]` emitted every collect_tick refresh.
- **M4-001 seeded-stat render smoke** (`tests/test_seeded_stat_
  smoke.pdx`, pdxwatch#7) — boot-smoke witness for the M2 widget
  stack. Seeds fixture values (4 CPUs @ 50 %, 8 GiB used, task_seen
  = 15) into a private CollectSnapshot .bss slot, drives each
  widget against a 256×128 BGRA back-buffer, digests the per-widget
  sub-rects, compares to hardcoded expected values, emits
  `pdxwatch seeded-stat ok` on all-pass. Expected-digest constants
  are **placeholders** (`0xFFFFFFFFFFFFFFFF`) that always fail on
  first run — see §4 for the freeze-after-first-green policy.
- **M4-002 click-cycle encoder-half smoke**
  (`tests/test_click_cycle_smoke.pdx`, pdxwatch#8) — state-machine
  transition contract for the CPU-bar detail-mode cycle. Emits
  `pdxwatch click-cycle ok` on all-pass (via the paideia-os QEMU
  smoke driver, gated by `pcc_run_all()`).
- **M4-003 `q`-quit encoder-half smoke**
  (`tests/test_q_quit_smoke.pdx`, pdxwatch#9) — keypress
  state-machine + scripted 'q' witness. Emits `pdxwatch quit ok`
  on all-pass.

## 3. What v1.2.0 explicitly does NOT ship (deferred)

Consumers relying on this release must know these gaps are real and
by design, not oversights:

- **Frozen M4-001 expected-digest constants** — the placeholder
  `0xFFFFFFFFFFFFFFFF` sentinels in `tests/test_seeded_stat_smoke.pdx`
  always fail on the first green build, gating the fingerprint
  `pdxwatch seeded-stat ok`. The freeze-after-first-green procedure
  is documented in the source file's `§PLACEHOLDER-FINGERPRINT
  POLICY`; a follow-up issue captures the freeze.
- **libpdx-event.M3-001 substrate wire-in** —
  `Input::input_poll_events` returns 0 unconditionally until the
  library reaches M3 and the `event_next` queue-drain body
  materialises. Tracked as a follow-up (`marker STUB(libpdx-
  event.M3-001)` at the source callsite).
- **libpdx-gfx / libpdx-font stub retirement** — the three widget
  modules (`widget_cpu.pdx` / `widget_mem.pdx` / `widget_net.pdx`)
  carry inline `pw*_gfx_fill_rect` / `pw*_gfx_draw_glyph` /
  `pwn_gfx_draw_line` stubs pending libpdx-gfx.M2-002 + libpdx-
  gfx.M2-003 + libpdx-font.M2-001. Tracked as **pdxwatch#14**
  ("pdxwatch: retire widget_cpu.pdx / widget_mem.pdx libpdx-gfx +
  libpdx-font stubs when M2-002 / M2-001 land").
- **widget_net.pdx unsigned-wrap on `task_seen` decrease** — a
  monotone-count assumption in the network sparkline produces false
  MAX spikes when the task pool shrinks. Tracked as **pdxwatch#15**
  ("Hotfix: widget_net (#5) unsigned-wrap on task_seen decrease").
- **`_start` binder / linkable ELF** — `manifest.pdxproj` `entry =
  Main::main` remains a forward-declaration; the M1-005 `_start`
  binder + `Main::main` call-frame is not landed in this milestone.
  `tools/build.sh` produces loose ELF64 objects under `build-out/`.
- **KIND_SURFACE mint + gfx_commit** — `caps.decl`'s `KIND_SURFACE
  (mint, commit, revoke)` is a forward declaration; no ring-3
  surface_open call fires yet. Blocks on libpdx-gfx.M1.

## 4. Substrate readiness (blocking the actual signed release)

**S1 — paideia-as toolchain ≥ 0.36.0 reachable.** The release build
invokes `paideia-as build --emit elf64` per `tools/build.sh`. The
0.36.0 floor covers the encoder revision the v1.1 pass across the
twelve mature R102 / R100 satellites was validated against (module-
basename-pascal enforcement, 2-op `imul reg,reg` mnemonic surface,
tightened test-mnemonic reservation, single-line `pub let` string
literals). `STATUS.md` tracks the toolchain version this repo is
tested against.

**S2 — `pkgs.paideia-os` mirror endpoint reachable.** Same
mirror-status caveat `libpdx-volume`'s runbook documents (as of
R102.M5-001 close: mirror endpoint not standing). The release is
"cut but not mirrored" until the endpoint lands; the signed
`manifest.pdxsig` still ships in the GitHub release attachment set
for out-of-band consumers.

**S3 — live release-line seed keys (Ed25519 + ML-DSA-65).** No
repo-resident seed key material by the paideia-release-line custody
discipline (`design/02-development-environment.md` §1164 — hardware-
backed TPM 2.0 or cloud KMS). The manifest at
`release/manifest.pdxsig.txt` carries
`SIGNATURE_PLACEHOLDER_PENDING_LIVE_SIGN` in every signature slot;
the dual-sign pass fills them in at operator tag time.

**S4 — `doc` M2 reachable.** pdxwatch does NOT ship a `.pdxdoc` at
this release (widget wire-in blocks on libpdx-gfx.M2 as noted in
§3 above; the user-facing "how to launch pdxwatch" doc requires a
real linkable binary the M1-005 milestone owns). A future release
adds `doc/pdxwatch.pdxdoc` alongside the `_start` binder landing.

---

## 5. Cut-a-release procedure

Mirrors `libpdx-volume`'s runbook shape (same tooling, same
release-line key custody).

**Pre-flight.**

    git fetch origin
    git switch main
    git pull --ff-only
    git status                                     # MUST be clean
    gh issue list --milestone M5 --state open --repo paideia-os/pdxwatch
                                                   # MUST be empty

**Step 1 — Version bump + CHANGELOG close.** Landed at M5-001 —
`manifest.pdxproj` `version = 1.2.0` and `CHANGELOG.md`'s
`## [1.2.0]` entry are the artefacts a future tag points at.

**Step 2 — Tag.** (Manual, main-performed; NOT run as part of this
milestone.)

    git tag -a v1.2.0 -m "pdxwatch v1.2.0 — M5-001 signed release + M4 witness triplet"
    git push origin v1.2.0

**Step 3 — Build the compiled artifact set.**

    bash tools/build.sh
    # produces build-out/collectors.o, main.o, widget_cpu.o,
    # widget_mem.o, widget_net.o, input.o, and the three
    # tests/test_*_smoke.pdx object files.
    # (M1-005 linkable ELF landing produces build-out/pdxwatch;
    # not part of this milestone.)

**Step 4 — Recompute the manifest hashes.**

    paideia-release fill-manifest \
        --source release/manifest.pdxsig.txt \
        --tree   . \
        --tag    v1.2.0 \
        --output build/manifest.pdxsig.filled.txt

**Step 5 — Dual-sign.**

    paideia-release sign \
        --manifest build/manifest.pdxsig.filled.txt \
        --key-ed25519  release-line-ed25519.sk \
        --key-ml-dsa65 release-line-ml-dsa-65.sk \
        --output   build/manifest.pdxsig

**Step 6 — Mirror push.**

    paideia-release mirror-push \
        --repo   https://pkgs.paideia-os/main/ \
        --pkg    pdxwatch \
        --version 1.2.0 \
        --files  build/pdxwatch \
                 caps.decl \
                 build/manifest.pdxsig

Expected mirror layout after push:

    /pkgs/pdxwatch-1.2.0/
        bin/pdxwatch                              # M1-005 landing
        caps.decl
        manifest.pdxsig

**Step 7 — Verify (in-tree witness).**

    bash tools/release-verify.sh release/manifest.pdxsig.txt
    # On all-pass echoes: pdxwatch 1.0.0 signed ok

The fingerprint identity `pdxwatch 1.0.0 signed ok` is
milestone-scoped (M5-001), not version-scoped — see §1. The
verify-witness is the fingerprint mechanism this release ships
in-tree; the QEMU smoke driver grep-gates on this string alongside
the peer widget fingerprints (`pdxwatch cpu-widget ok`, `mem-widget
ok`, `net-widget ok`, `input ok`, `seeded-stat ok`, `click-cycle
ok`, `quit ok`).

**Step 8 — GitHub release.**

    gh release create v1.2.0 \
        --title "pdxwatch v1.2.0 — signed release closer" \
        --notes-file release/RELEASE-1.2.0.md \
        build/manifest.pdxsig \
        caps.decl

---

## 6. Consumers who can rely on this release today

pdxwatch is a **user-launched GUI tool**, not a library — the
consumers are end-users running `pkg install pdxwatch` on a live
paideia-os system, plus downstream monitoring daemons reading the
`SysStatRecord@0.1` semantic pipe. Both surfaces are stable at
v1.2.0 with the noted stubs (§3) documented.

- The `SysStatRecord@0.1` semantic pipe (schema tag
  `0x41545353` = `'SSTA'` LE) emits one 160-byte record per
  collect_tick refresh through `sys_semantic_send` (sysno 115).
  Byte-for-byte prefix of `CollectSnapshot[+32..+192]`; see
  `caps.decl` `declares_output_schemas` for the field layout.
- The widget stack renders into a caller-supplied BGRA8888
  back-buffer at the three fixed rects the M2 landings document.
  Consumers linking against pdxwatch's back-buffer directly are NOT
  supported (M1-005 packages the compositor wire-in as one closed
  binary).
- The M4 witness triplet gates every paideia-os smoke run against
  this pdxwatch commit — a downstream regression in the M2 widget
  stack fails the `pdxwatch seeded-stat ok` fingerprint (once its
  digests are frozen — see §3), a click-cycle regression fails
  `pdxwatch click-cycle ok`, a 'q'-quit regression fails
  `pdxwatch quit ok`.

## 7. Verification (consumer side)

    pkg install pdxwatch --verify-only     # dry run, no install
    pkg keys show paideia-release-line     # inspect the signer

AND-semantics per the hybrid scheme: both Ed25519 and ML-DSA-65 MUST
verify; either failure REJECTS the package. Not runnable until the
placeholder signature block in `release/manifest.pdxsig.txt` is
replaced by a real dual-sign pass per §4 above.

---

## 8. What lands at M5-001 (this milestone)

Repo-side, M5-001 lands the source form of the release:

- `manifest.pdxproj` — `version = 1.1.0 -> 1.2.0`; `release:` block
  extended with `manifest_sig`, `release_note`, and `verify_witness`
  entries.
- `release/RELEASE-1.2.0.md` — this document.
- `release/manifest.pdxsig.txt` — release manifest source form,
  every hash and every signature slot a documented placeholder.
- `tools/release-verify.sh` — in-tree witness that emits
  `pdxwatch 1.0.0 signed ok` on dual-sig verify-pass. Verify pass
  is stubbed at this landing (S3 above); the script's structural
  contract is what M5-001 lands.
- `CHANGELOG.md` — `## [1.2.0] - 2026-09-11` entry summarising M4
  witness triplet + M5-001 release-closer.
- `STATUS.md` — M5-001 marked landed, `Version:` line bumped, M4-001
  / M4-002 / M4-003 rows flipped to landed.

**Not performed at this milestone:** the git tag itself (main's
manual step, once this landing is reviewed), the mirror push (S2
above — mirror not standing), the dual-sign pass (S3 above — no
repo-resident key material). The follow-up hotfixes at pdxwatch#14
and pdxwatch#15 remain open against v1.2.0 and target a v1.2.1
patch release.

## 9. Post-v1.2.0 roadmap

- **v1.2.1** (imminent) — pdxwatch#15 hotfix (widget_net unsigned-
  wrap on `task_seen` decrease). Single-file `src/widget_net.pdx`
  change; no manifest / caps.decl churn.
- **v1.3.0** — pdxwatch#14 stub retirement (widget_cpu / widget_mem
  / widget_net libpdx-gfx + libpdx-font wire-in), gated on
  libpdx-gfx.M2-002 + libpdx-gfx.M2-003 + libpdx-font.M2-001
  landings.
- **v1.4.0** — libpdx-event.M3-001 wire-in retires the
  `Input::input_poll_events` stub; unbounded main loop replaces
  the `PW_MAIN_TICK_BUDGET = 32` bounded shape.
- **v2.0.0** — M1-005 `_start` binder + `Main::main` call-frame +
  linkable ELF at `build-out/pdxwatch`; user-facing
  `doc/pdxwatch.pdxdoc` first ships. This is the release the M5-001
  fingerprint identity (`pdxwatch 1.0.0 signed ok`) would be
  renamed at, since v2.0.0 first crosses the "user launches
  pdxwatch and sees a window" threshold the M5-001 name originally
  anticipated.

---

Closes #10.
