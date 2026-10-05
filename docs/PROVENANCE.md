# Publication-safe rev7 production provenance — v1.0.0

Production approval: **PRODUCTION_APPROVED_PUBLICATION_SAFE_REV7**.
Exact shipped payload: `payload/ds3-uhid-hook/zygisk/armeabi-v7a.so`.
SHA256: `e4183947d3ef3917b4b8cc261b3a869e6190aedcd59c87728b24061a578447cf`.
Final exact-binary live acceptance: **PASS**, 2026-10-04.
Publication packaging is offline; no production rebuild is performed.

## Source lineage and local changes

The source baseline is the publication-safe rev6 implementation, with source
SHA256 `19c3d173ae1a9d9811b76a208455a5013fa1b131b43c4fb8bf921c87df1bf3e7`.
The production rev7 source SHA256 is
`f10bc6b2d36e912b3573ba215c2572423edb43dfe0c737f3652d7c8649ce0798`.
The only semantic addition is the locally authored BL/LR correction after
branch composition: `if (g_sites[i].kind != 2) want[3] |= 0x40u;`.
OUTPUT and SET use BL; the completion RSP site remains B.W. No implementation
from the old provenance-sensitive production tree was imported for this rebase.
SET/OUTPUT/RSP helpers, FSM, replies, maps parsing, rollback, lifecycle and
generated executable veneers are unchanged. Normalized code comparison and
ABI/register/SP/LR tests reject unexpected functional changes.

Project-authored implementation and local assembly/generated veneers use the
project MIT notice. Third-party inputs retain their own terms below; this is
not a relicensing of vendor firmware or an unknown SHA implementation.

## Independently implemented SHA-256

The project SHA-256 implementation was independently authored from the algorithm
definition in FIPS PUB 180-4 sections 4.1.2, 4.2.2, 5 and 6.2:
https://doi.org/10.6028/NIST.FIPS.180-4 . No external implementation text or old
uncertain implementation body was used for this replacement.
Independent header SHA256:
`b5edb410b63fd53351a93cead8636617eca59f38dc63577b766fed026465c33d`.
Mathematical standard constants are algorithm facts, distinct from implementation
text. The old unknown-provenance SHA implementation is absent from the payload.
Native known-answer tests cover empty input, abc, standard padded/multi-block
vectors, a million a, 16 block/padding boundaries and private full-library fixtures.
The exact same header is compiled into ARM production and the host test DLL.

* independent SHA-256 implementation: YES
* sha256 provenance resolved: YES
* old unknown-provenance sha256 absent: YES

## Digest-only compatibility validation

All three site checks use cryptographic fingerprints over runtime windows of
4, 4 and 26 bytes. Raw vendor instruction comparison arrays are absent from the
production source/binary and public profile. The local Site B transformation
likewise uses offset, length and digest for the original window; only the locally
authored replacement instruction is supplied. SHA fingerprints, addresses, sizes
and BuildID are factual compatibility metadata, not copied instruction sequences.
The exact whole-library SHA/size pins the supported BuildID at runtime; the public
transform also checks BuildID explicitly. All validation precedes writes. Rollback
preserves actual bytes read from the running process, not shipped vendor bytes.
Native validation-loop tests reject all 34 one-byte window mutations and verify
exact saved originals. Vendor-data scans reject historical raw-array source/ELF
negative controls and pass the production payload and entire public tree.
No stock or transformed vendor/system `libbluetooth.so` is distributed.

* raw vendor signature redistribution eliminated: YES
* per-site digest/fingerprint validation retained: YES
* whole-library SHA/BuildID validation retained: YES

## Retained permissive third-party inputs

See `THIRD_PARTY_NOTICES.md` and the complete license texts in `LICENSES/`.

| Incorporated input | Origin / terms |
|---|---|
| Adapted public Zygisk API and entry callbacks | John Wu; permissive public-domain predecessor / 0BSD |
| JNI inline wrappers and Bionic pthread_atfork glue | AOSP 2006/2015; Apache-2.0 |
| Bionic startup/exit and CRT metadata | AOSP 2012/2013; BSD-2-Clause |
| Retained compiler-rt ARM builtins | LLVM contributors; Apache-2.0 WITH LLVM-exception |

Zygisk API source-family references:
https://github.com/topjohnwu/Magisk/blob/2c092ffdef46512e94dd1b9c974e4b280e1da7fa/native/jni/zygisk/api.hpp
and the separately licensed API:
https://github.com/topjohnwu/Magisk/blob/1565bf5442e10b0f1b1908856f21e45703baa29a/native/src/zygisk/api.hpp .
The local adaptation reduces unused API surface, renames table storage, simplifies
accessors and uses static callback wrappers. It does not incorporate Magisk core.
The packaged toolchain identity is Android NDK r30 `30.0.16248370`, Clang 21.0.0.
An exact upstream Bionic source commit is not recorded; the packaged CRT input
identity and applicable permissive notices are established. LLVM base:
`2d287f51eff2a5fbf84458a33f7fb2493cf67965`. Object-embedding exceptions apply.
Four dynamic dependencies remain `libc.so`, `libdl.so`, `liblog.so`, `libm.so`;
none is bundled. No BlueZ/Fluoride implementation import was established.
No Magisk core, NDK header collection, compiler, Android platform-tools or firmware
library is included. Known third-party notices are complete.

* unresolved code-bearing provenance: NO
* provenance gate: PASS

## Live acceptance and publication scope

The exact shipped SHA passed deployment with one reboot, current-boot STG0-STG5
and I00-I13, runtime hook/branch/literal checks, whole-library and site fingerprints,
a controlled disconnected start, one requested P3, successful sony_probe/main and
motion input registration, and one Cross press/release. Numeric capture verified
EV_KEY code `0x0130` / `304`, values `1` and `0`; labelled capture showed its
BTN_GAMEPAD / BTN_SOUTH alias. Bluetooth remained healthy, crash count `0 -> 0`,
tombstones unchanged. Rollback was not required.
No private controller/box identifiers, logs, dumps or live raw memory evidence
are distributed. Public installer/rollback transactions have offline coverage;
their end-to-end live execution is not claimed by the payload acceptance.
Player-number LED blinking remains unresolved; this is not a validated LED fix.
GitHub publication is a separate action, not part of offline packaging.
