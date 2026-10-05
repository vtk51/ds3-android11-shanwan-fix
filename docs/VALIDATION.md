# v1.0.0 validation

Approved production payload SHA256:
`e4183947d3ef3917b4b8cc261b3a869e6190aedcd59c87728b24061a578447cf`.
Approval: **PRODUCTION_APPROVED_PUBLICATION_SAFE_REV7**.

## Offline payload verification

* Publication-safe baseline and exact one-line BL/LR source delta verified.
* Independent SHA native known answers, padding/block boundaries and private
  whole-library fixture digests PASS; old uncertain implementation excluded.
* Actual digest validation loop saves runtime originals and rejects all 34
  one-byte mutations. Whole-library/BuildID/Site B/site-window gates fail closed.
* Old and candidate functional regressions, SET ABI/gate/pending, OUTPUT/completion,
  extracted reply/FSM, veneer/layout crash negative controls and register/SP/LR
  tests PASS. No diagnostic trace state ships.
* 95 normalized-exact code blocks versus publication-safe baseline; only installer
  and three independently decoded linker displacements differ. All veneer bytes
  and expected helper/FSM/input logic unchanged. Unexpected semantic delta NONE.
* Provenance, complete permissive notices and vendor-byte cleanliness PASS.

## Exact-binary controlled live acceptance — 2026-10-04

One deployment reboot; exact SHA active; STG0-STG5/I00-I13, OUTPUT/SET BL,
RSP B.W, fingerprints, executable veneers and literals PASS. Controlled
disconnected starting state, one P3, sony_probe and main/motion input registration
PASS. One Cross press/release verified by both labelled and numeric getevent:
EV_KEY BTN_SOUTH / BTN_GAMEPAD / `0x0130` / `304`, press `1`, release `0`.
Controller remained connected, Bluetooth healthy, crash count `0 -> 0`, tombstones
unchanged; no rollback required. No final-binary LED or separate reconnect
acceptance is claimed. LED indicators 1-4 may continue slowly blinking.

## Offline public package checks

Run `tests/run.ps1 -RequirePublishable`. The suite requires exact approved payload,
license/provenance, vendor-byte exclusion, no diagnostics/vendor libraries,
exact-match compatibility, wrong SHA/ABI/firmware fail-closed, actual installer
DryRun zero-write spies, cached HID idempotency, backup/rollback plan/transaction
invariants, complete public-tree privacy/secret scanning and checksums.
GitHub Actions runs these device-free checks and archive extraction on Windows.
Extracted checks require only PowerShell and shipped files; no workspace, NDK,
device, authentication or private verification fixture is needed.
The packaging procedure creates a fresh ZIP, validates every ZIP entry against
the public tree and reruns the publishable suite from a fresh extraction.
`CHECKSUMS.txt` inside the package covers all shipped files except itself.
The final ZIP SHA is recorded in the distribution-adjacent `CHECKSUMS.txt`,
outside the ZIP, avoiding a self-referential archive checksum.

Public install/rollback scripts have offline coverage only; the live result above
validates the exact payload/mechanism, not end-to-end public transaction execution.
No Android commands, reboot, payload rebuild or GitHub publication are performed
during final packaging.
