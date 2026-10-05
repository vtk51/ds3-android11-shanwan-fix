# Proven mechanism

## USB master and admission

DS3 USB cable setup stores the host/master Bluetooth BDADDR in the controller.
This is not conventional BR/EDR pairing and does not produce a normal shared
BR/EDR link key. The clone initiates a connection to that master when P3 is pressed.
The firmware separately admits only a recognized bonded address; a previously
established address-specific bond admission was present in the proven setup.
Cached HID metadata alone does not bypass that admission. This installer requires
the existing admission record rather than introducing an untested bond generator.

## HID security and cached SDP

The incoming Android HID path passes `HID_SEC_REQUIRED` (`0x8000`) to
`HID_HostAddDev`. Authentication against the USB-setup clone fails without a
normal BR/EDR key. Proven Site B changes exactly four Thumb-2 bytes at file
`0x20769a`, VA `0x20869a`. The original window is pinned by SHA-256
`3102f2d928dcf460937069054df1d536afa2a772796dff048098281dd4ef5d6a`;
project-authored replacement: `4f f0 01 01`, `MOV.W r1,#1`.
`1` is `HID_VIRTUAL_CABLE`, a nonzero attribute forcing a write without the security
bit. **All incoming bonded HID through this function are affected.** Site A
machine code and outgoing AddDev sites are untouched.

The clone's SDP behavior required a cached HID record. Persisted `HidAppId=6`
selects the gamepad cached branch instead of initiating remote SDP. The proven
`HidAttrMask=117` combines virtual cable, reconnect initiate, battery, remote wake
and supervision-timeout-present bits; it excludes `HID_SEC_REQUIRED`.
The canonical 148-byte descriptor matches both captured USB data and BlueZ's
Sixaxis descriptor. SSR values are `65535`, not the loader's missing-key default
`0`. The merge preserves existing bond keys and unrelated sections and never
adds a second controller section. Bluetooth must be quiescent before the atomic
same-directory rename; concurrent changes are rejected by the original config hash.

## UHID reply and publication-safe production rev7

The relevant Android path forwards UHID SET_REPORT but the
`bta_hh_co_set_rpt_rsp` completion only logs unsupported behavior, without a
matching `UHID_SET_REPORT_REPLY`. The kernel hid-sony operational-mode request
therefore cannot complete input setup.

Production rev7 installs verified Thumb-2 BL calls for OUTPUT forward at VA
`0x14d95e` and SET forward at `0x14d986`; completion at `0x14df4c` remains B.W.
The call-sites preserve LR by setting the BL bit only when site kind is not RSP:
`if (g_sites[i].kind != 2) want[3] |= 0x40u;` after `enc_bthumb(...)`.
Runtime addresses are derived from PT_LOAD/maps and verified against stock
cryptographic window fingerprints. Exact size/SHA pin, bounded maps discovery,
digest gates and
transactional rollback make an unsupported target a no-op inside the module too.
Veneers use a verified nearby RX page and indirect interworking calls to ARM hooks.

The SET hook takes `(p_dev,id,type,size,rnum,data)`, gated by FEATURE `3`, size
`5`, report `0xf4`. Handle is a byte at `p_dev+4`. Per-handle pending state captures
request id and generation. Completion matches the handle, consumes once, resolves
the current device/fd (`+0x10`) and sends packed event `14` with the captured id,
err `0` for status `0`, otherwise `EIO=5`. Stock `uhid_write` writes 4380 bytes.
OUTPUT spoils an overlapping pending transaction to avoid false success. Busy
requests receive conservative errors; entries become stale at 15 seconds and
request ids can be reused after completed sessions. No diagnostic trace ring ships.

The final SET ABI marshaling correction adds `mov r3,r2; mov r2,r1` before existing
id marshaling, after preserving the original data as argument 6. Size/type now
reach the C hook in the intended argument positions. Stock r0–r3, callee-saved
registers and aligned SP are restored after helper clobbers. OUTPUT and completion
mechanisms are unchanged. The exact final binary passed successful `sony_probe`,
motion/main input registration and one controlled Cross press/release. Existing
reconnect logic is retained; a separate final-binary reconnect test is not claimed.

## Pinned target

Android API `30`, Bluetooth `armeabi-v7a`, `/system/lib/libbluetooth.so`, 4138248
bytes; BuildID `bc23b5e2a1463ef9218d6318663d54be`. Exact pins, site lengths and
SHA-256 window fingerprints are in `profiles/ohm-api30-arm32.json`. Firmware
fingerprint alone never authorizes patching. No stock/patched vendor binary is
included. The shipped approved production payload SHA256 is
`e4183947d3ef3917b4b8cc261b3a869e6190aedcd59c87728b24061a578447cf`.
It uses independent project SHA-256 and hashed runtime-site validation, preserving
runtime-original rollback bytes. Whole-image identity also pins the exact BuildID;
the public transform checks BuildID explicitly. Provenance and exact-binary
live acceptance PASS, as documented in `PROVENANCE.md`.
