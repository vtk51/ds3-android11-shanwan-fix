# Adding a firmware profile

Unknown API/fingerprint/ABI/stock hash/BuildID/signatures return `UNSUPPORTED`.
Do not relax pins or substitute addresses. An unknown Magisk/SELinux environment
is `UNSAFE_STATE`, not an automatic invitation to use a legacy repair.

Run `scripts/collect-diagnostics.ps1` using your own platform-tools. Review the
small JSON before sharing. It includes selected firmware properties, Bluetooth
ELF architecture and library-only maps, library hashes/BuildID where ELF32 notes
are available, current-profile-offset signatures, Magisk/Zygisk/SELinux and DS3
identity observations without controller addresses. ELF64 BuildID extraction is
not implemented: obtain it offline with a trusted readelf and add only the BuildID
to the evidence. No full config, personal keys, serials, unrelated logs or dumps
are required. The collector writes host output only, never patches the device.

A new profile needs independent reverse engineering of Site B, PT_LOAD mapping,
all hook sites/call ABI, handle/fd offsets, UHID ABI, completion status and lifecycle,
plus a compatible licensed hook artifact and offline regressions. Then separately
authorize live connection/reconnect/input acceptance and archive sanitized results.
The current rev6 pins one target hash and cannot support a different library merely
by editing JSON. Do not distribute any extracted firmware library.

Schema contract: `schemaVersion=1`; required identity fields are `id`, `androidApi`,
`fingerprint`, `bluetoothAbi`, `magiskVersionCode`, `zygiskApi`, `selinux`; `library`
requires path/size, 64-hex SHA pins, 32-hex BuildID/offset, Site B offset and exact
four-byte original/replacement, plus offset/hex signatures. `hook` pins production
hash/size/ELF class/machine, process/ABI/gate assumptions. `cachedHid` has ten keys
and exactly 148 descriptor bytes. `masterBdaddr` is `MANUAL_GATE` until proven
automation and its license exist. `publication.ready` is a separate clearance gate.
The offline schema tests enforce this contract and the exact known profile values.
