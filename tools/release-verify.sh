#!/usr/bin/env bash
# pdxwatch -- release-verify witness (M5-001, pdxwatch#10).
#
# Verifies a filled `manifest.pdxsig` against the paideia-release-line
# dual-signature scheme (Ed25519 + ML-DSA-65, AND-semantics per
# design/02-development-environment.md §1140). On all-pass, emits the
# fingerprint identity `pdxwatch 1.0.0 signed ok` to stdout -- the
# M5-001 witness string the paideia-os QEMU smoke driver grep-gates
# on, alongside the peer widget fingerprints (`pdxwatch cpu-widget
# ok`, `mem-widget ok`, `net-widget ok`, `input ok`, `seeded-stat
# ok`, `click-cycle ok`, `quit ok`).
#
# The fingerprint identity is MILESTONE-scoped (M5-001), not
# VERSION-scoped -- see release/RELEASE-1.2.0.md §1 for the version-
# name reconciliation. It is emitted verbatim regardless of the
# `package-version` field the input manifest carries.
#
# Usage:
#   tools/release-verify.sh [release/manifest.pdxsig.txt]
#
# If no path is passed, defaults to `release/manifest.pdxsig.txt` in
# the repo root (source form; every signature slot a placeholder --
# invocation refuses fast with a clear message pointing at the
# operator's cut-a-release procedure per RELEASE-1.2.0.md §5).
#
# Substrate readiness (see RELEASE-1.2.0.md §4):
#   S1: paideia-as >= 0.36.0                (bash `paideia-as --version`)
#   S2: `paideia-release verify` reachable  (from paideia-release
#                                            crate; not resident in
#                                            this repo)
#   S3: signature slots FILLED              (source form is
#                                            SIGNATURE_PLACEHOLDER_*
#                                            and refuses)
#
# Requires paideia-release >= 1.0.0 at operator runtime. Not run at
# M5-001 landing (S3 gates); the script's structural contract is what
# this milestone lands.

set -euo pipefail

FINGERPRINT="pdxwatch 1.0.0 signed ok"
DEFAULT_MANIFEST="release/manifest.pdxsig.txt"
PLACEHOLDER_SENTINEL="SIGNATURE_PLACEHOLDER_PENDING_LIVE_SIGN"

manifest_path="${1:-$DEFAULT_MANIFEST}"

if [[ ! -r "$manifest_path" ]]; then
  echo "release-verify: cannot read manifest at '$manifest_path'" >&2
  echo "release-verify: expected release/manifest.pdxsig.txt " \
       "(source form) or a filled manifest.pdxsig (binary form)" >&2
  exit 2
fi

# S3 gate: source-form manifest carries placeholder signatures. Refuse
# with a pointer at the cut-a-release procedure per RELEASE-1.2.0.md §5
# rather than silently emit a green fingerprint over unsigned bytes.
if grep -q "$PLACEHOLDER_SENTINEL" "$manifest_path"; then
  echo "release-verify: manifest '$manifest_path' contains" \
       "$PLACEHOLDER_SENTINEL slots" >&2
  echo "release-verify: this is the source-form manifest. Run the" \
       "cut-a-release procedure per release/RELEASE-1.2.0.md §5" \
       "(Steps 4 + 5) to produce a filled manifest.pdxsig, then" \
       "re-invoke this script against that binary." >&2
  exit 3
fi

# Delegate to `paideia-release verify` (dual-sig AND-verify). If the
# tool is not on PATH, refuse; S2-blocked configurations should not
# see a false-green fingerprint.
if ! command -v paideia-release >/dev/null 2>&1; then
  echo "release-verify: 'paideia-release' not found on PATH" >&2
  echo "release-verify: substrate S2 (paideia-release >= 1.0.0) not" \
       "reachable; see release/RELEASE-1.2.0.md §4 S2 for the" \
       "mirror-endpoint / tooling status." >&2
  exit 4
fi

if paideia-release verify \
     --manifest "$manifest_path" \
     --signer   paideia-release-line \
     --scheme   hybrid-ed25519+ml-dsa-65 \
     >/dev/null 2>&1; then
  echo "$FINGERPRINT"
  exit 0
else
  echo "release-verify: dual-signature verification FAILED for" \
       "'$manifest_path'" >&2
  echo "release-verify: at least one of (Ed25519, ML-DSA-65)" \
       "signatures did not verify; AND-semantics rejects the" \
       "package per design/02-development-environment.md §1140." >&2
  exit 5
fi
