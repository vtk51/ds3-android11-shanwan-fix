# DS3 Android 11 SHANWAN fix

Bluetooth support for SHANWAN/compatible DualShock 3 clones on **one known
Android 11 firmware profile**. Tested USB VID:PID: `054c:0268`.
This is **not universal**: unsupported firmware returns `UNSUPPORTED` before
device mutation. The current profile requires root, Magisk 24.3 / `24300`,
Zygisk API v3 enabled, ARM32 Bluetooth userspace (`armeabi-v7a`) and the proven
permissive SELinux environment. No new SELinux policy is supplied.

> **1.0.0: approved publication-safe rev7 production payload included.**
> Exact SHA256: `e4183947d3ef3917b4b8cc261b3a869e6190aedcd59c87728b24061a578447cf`.
> Approval: `PRODUCTION_APPROVED_PUBLICATION_SAFE_REV7`; controlled live
> acceptance PASS. Independent project SHA-256 and digest-only site validation
> are retained. See [provenance](docs/PROVENANCE.md).

## Proven result

This exact production binary passed controlled Bluetooth connection, `sony_probe`,
input registration and one Cross / `BTN_SOUTH` (`0x0130` / `304`) press/release,
with unchanged Bluetooth crash count and tombstones. Existing reconnect/reply
behavior is retained from the verified lineage; a separate reconnect test of
the final binary is not claimed. The public install/rollback transactions have
offline coverage; their end-to-end device execution is not claimed. LED indicators **1/2/3/4
may keep slowly blinking** rather than show the player number; this unresolved
cosmetic issue is not fixed in this release.

## Architecture

```text
USB 054c:0268 -- manual master-BDADDR/readback --> box Bluetooth adapter
                               |
existing admitted bond --> cached HID metadata (app=6, mask=117, 148 bytes)
                               |
device stock library --> exact Site B transform --> Magisk overlay
                               |
DS3 BR/EDR --> Android HID --> UHID SET --> production rev7 pending/completion
                               |                         |
                               +<--- matching SET reply -+
                               |
                       hid-sony --> SHANWAN input --> Cross
```

Site B affects **all incoming bonded HID** traversing that Android function,
not just DS3; it replaces the HID security-required attribute with virtual-cable.
It does not globally bypass the separate incoming bond-admission check.

## Requirements and preparation

* Windows PowerShell 5.1+ or PowerShell 7; user-supplied Android platform-tools
  (`adb` on PATH). This repository does not bundle ADB, firmware or repair binaries.
* Exactly one authorized ADB device, or pass `-Serial <ADB_SERIAL>` explicitly.
  Keep ADB/root authorization available after the planned reboot.
* Exact `profiles/ohm-api30-arm32.json` fingerprint, API, ARM32 process identity,
  library size, BuildID, stock SHA256, Site B and hook window fingerprints.
* Enabled Bluetooth, working Magisk mirror and busybox, enabled Zygisk. Unknown
  Magisk versions are `UNSAFE_STATE`; there is no automatic legacy repair.
* Exactly one existing SHANWAN bond section with previously established admission
  (`LinkKeyType=4`, a 32-hex `LinkKey`). Cable setup alone does not make this bond.
  The package does not invent or distribute a development bond key. Missing or
  ambiguous admission/configuration stops with a manual gate / `UNSAFE_STATE`.
* USB master setup: use your independently trusted DS3 pairing tool to detect
  `054c:0268`, read its current master, change it only when different from the
  box's actual Bluetooth MAC and verify readback. No proven reusable USB writer
  with established provenance was found in the project. `MANUAL_GATE` therefore
  asks you to enter the independently verified box MAC. Examples use placeholders,
  never development addresses. Do not enter a value without reading it back.

## Normal workflow

```powershell
.\scripts\install.ps1 -DryRun
.\scripts\install.ps1
```

The first command inspects and classifies the device and prints the plan. It
performs zero installer writes: no push/pull, backup, pairing, config change,
module change or reboot. ADB/root themselves may maintain ordinary system logs.
`preflight.ps1` returns exactly one of `SUPPORTED`, `ALREADY_INSTALLED`,
`UNSUPPORTED`, `UNSAFE_STATE`. Classification describes device compatibility;
the separate payload gate verifies the included approved production binary.

The supported installer performs compatibility checks, verified backup, the USB
master manual gate, atomic cached HID merge, both module installations and
on-device checksums, **exactly one normal reboot**, bounded ADB/root wait and
verification. It checks Magisk/Zygisk, Magic Mount, current-boot STG0–STG5,
I00–I13 (PID-attributed I00/I01 and boot-fresh completion stages), Bluetooth health,
pauses for one P3/PS press and detects
SHANWAN main/motion inputs. Add `-CrossTest` for a bounded 30-second Cross
press/release `getevent` check. `ALREADY_INSTALLED` verifies only, with no reboot.
No reboot retry or automatic rollback is attempted on failure.

```powershell
.\scripts\preflight.ps1
.\scripts\verify.ps1 -AskP3 -CrossTest
.\scripts\collect-diagnostics.ps1
```

## Backups and rollback

Backups use timestamp/GUID transactions in `/data/adb/ds3-fix/transactions/` and
`%LOCALAPPDATA%/DS3Fix/backups/`. The manifest records config/module existence,
recursive regular-file hashes, owner/mode/context metadata, archive SHA256, stock
identity and transaction metadata. The archive is independently extracted and
hash-checked before proceeding, then checked on the host. A failed backup stops
installation. Backups contain your own Bluetooth configuration: keep them private.
Never commit local backups, generated libraries or diagnostics to this repository.

```powershell
.\scripts\rollback.ps1 -Transaction <TRANSACTION_ID> -DryRun
.\scripts\rollback.ps1 -Transaction <TRANSACTION_ID>
```

Rollback restores the selected transaction's config and previous module states,
including absence, removes the installer lock/temp config, restores modes/owners
and SELinux contexts, verifies file hashes and requests one reboot. Backup material
is retained unchanged. It never selects an arbitrary/latest transaction.
The USB controller's master is a manual external step; restore its previous master
using your trusted tool if you changed it. A lost ADB connection requires recovery
access to disable the modules; see troubleshooting.

## Identity, offline validation and scope

| Artifact | SHA256 |
|---|---|
| Device stock `libbluetooth.so` (not shipped) | `153cb547688608e4070276e1f688d37a8eecb9146c491a34e3d5e793f7763caa` |
| Locally transformed overlay (not shipped) | `68249b8126a3160fdf17a93b464762d8517cea2d25c125aacb4fddb47fddb86c` |
| Approved publication-safe rev7 (included) | `e4183947d3ef3917b4b8cc261b3a869e6190aedcd59c87728b24061a578447cf` |

```powershell
.\tests\run.ps1
.\tests\run.ps1 -RequirePublishable
```

The first runs device-free automation/integrity/hygiene tests. The second also
enforces the approved payload/provenance gate. GitHub Actions uses
offline local checks on its runner; no device or ADB credentials are required.
`CHECKSUMS.txt` covers shipped files except itself. The ZIP's hash is in the
adjacent distribution `CHECKSUMS.txt`; embedding the hash of an archive in itself
would be circular. Extracted tests need only PowerShell and shipped files.
The payload has passed offline provenance/regression checks and exact-binary
live acceptance. Final packaging is offline and does not rebuild or deploy it.
The release ZIP is newly generated from this clean tree; its checksum is recorded
outside the archive. GitHub publication is a separate operation.

Further reading: [technical details](docs/TECHNICAL.md), [porting](docs/PORTING.md),
[troubleshooting](docs/TROUBLESHOOTING.md), [known issues](docs/KNOWN_ISSUES.md).
Полная русская инструкция: [README_RU.md](README_RU.md).
