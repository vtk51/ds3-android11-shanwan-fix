# Troubleshooting

* `UNSUPPORTED`: wrong firmware/API/ABI/library identity or signatures. Collect
  minimal profile diagnostics. No device patch should have happened.
* `UNSAFE_STATE`: missing root, disabled Zygisk, unproven Magisk/SELinux environment,
  stale installer lock/pending modules, missing or ambiguous existing admission.
  Correct the specific state and run preflight again. No guessed bond key is made.
* `PAYLOAD_MISSING_OR_UNLICENSED`: the publication-safe candidate is not yet
  live-accepted. `PROVENANCE_RESOLVED_PENDING_LIVE_ACCEPTANCE` intentionally
  keeps the existing installation gate closed until separate live acceptance.
* `MANUAL_GATE`: use your trusted USB pairing tool, detect `054c:0268`, read master,
  change only if required and verify readback against the box adapter MAC. Cable
  setup alone is not conventional Bluetooth pairing.
* `CONFIG_RACE` / `BLUETOOTH_STOP_TIMEOUT`: commit stopped rather than replacing
  a configuration that is still being written. Do not bypass the quiescence gate.
  The new public transaction scripts have only offline coverage, not a new live run.
* `BACKUP_VERIFICATION_FAILED`: stop; retain transaction material. No supported
  installation can proceed without verified archive contents and host hash.
* `STAGE_FAILED`, `STALE_STAGE`, `I13_NOT_COMMITTED`: an armed marker is not
  success. Check current-boot and PID attribution. Do not retry automatic reboot.
* `MAGIC_MOUNT_FAILED`: verify Magisk environment, mirror and module enablement.
  A directory on disk is not proof of an active mount.
* `SHANWAN_INPUT_MISSING`: disconnect USB, press P3 once after postboot checks.
  The input event number is discovered dynamically, not assumed to be event11.
* `CROSS_ACCEPTANCE_FAILED`: repeat only a separately requested bounded button
  capture on the identified main node; motion input is not the button node.

## Historical Magisk DATABIN failure

The proven old failure was Magisk `24300`, an empty `/data/adb/magisk/`, log
`Magisk environment incomplete, abort`, and source
`/data/app/Magisk/lib/arm/libbusybox.so` SHA256
`8365306415d5461f9a7b4bc28c7a90697150a002d28d5cdf43b361640eeca687`.
A busybox-only repair was proven for that exact state. This release **stops**
instead of performing it. If your environment is healthy, no repair is needed.
For the exact signature, independently back up `/data/adb`, verify version,
directory emptiness and source hash, and follow a separately reviewed repair
procedure. Unknown versions or hashes must not receive this historical repair.

## Recovery and selected rollback

Record the transaction id printed by installation. Run `rollback.ps1 -Transaction
<TRANSACTION_ID> -DryRun`, then the same command without `-DryRun` to restore.
The archive/script hashes must match; backup files are never overwritten.
Do not run rollback with arbitrary transaction paths or copied foreign manifests.
If ADB/root is unavailable, use your device's established recovery method to place
a `disable` file in `/data/adb/modules/ds3-hid-nosec` and
`/data/adb/modules/ds3-uhid-hook`, then boot normally and restore the selected backup.
Do not flash boot images or apply generic Magisk repairs from this package.
