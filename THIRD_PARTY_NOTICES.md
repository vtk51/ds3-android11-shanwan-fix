# Third-party notices — publication-safe rev7 production v1.0.0

These are engineering incorporation and provenance facts. The project license
applies to original project contributions; it does not relicense third-party code.
These notices cover approved payload SHA256
`e4183947d3ef3917b4b8cc261b3a869e6190aedcd59c87728b24061a578447cf`.
The rev7 BL/LR correction is original project code; no new third-party component
was added by the rebase from publication-safe rev6.

## Magisk/Zygisk public API

Copyright 2022 John "topjohnwu" Wu. `LICENSES/Zygisk-0BSD.txt`.
The adapted API header and callback entry wiring originate in the separately
permissively licensed public Zygisk API, not the GPL-licensed Magisk core.
Public-domain predecessor: Magisk v24.3, commit
`2c092ffdef46512e94dd1b9c974e4b280e1da7fa`, `native/jni/zygisk/api.hpp`.
0BSD corroboration: commit `1565bf5442e10b0f1b1908856f21e45703baa29a`,
`native/src/zygisk/api.hpp`. Local modifications reduce unused API surface,
rename table storage, simplify accessors, and use static callback wrappers.

## Android JNI and Bionic CRT

Copyright (C) 2006 The Android Open Source Project — JNI inline wrappers.
Copyright (C) 2015 The Android Open Source Project — pthread_atfork CRT glue.
Apache License 2.0: `LICENSES/Apache-2.0.txt`.

Copyright (C) 2012, 2013 The Android Open Source Project — Bionic startup,
exit/atexit glue and end metadata, BSD-2-Clause:
`LICENSES/Bionic-BSD-2-Clause.txt`.
Binary inputs are packaged NDK r30 `30.0.16248370` CRT objects for ARM/API30.
The precise upstream Bionic source commit is not recorded; packaged object
identity is established, and the known BSD/Apache notices are retained.

## LLVM compiler-rt

LLVM project contributors; Apache-2.0 WITH LLVM-exception:
`LICENSES/LLVM-Apache-2.0-with-LLVM-exception.txt`.
NDK r30/LLVM 21 packaged ARM builtins implement cache flushing, AEABI memory
copy and integer division. LLVM base:
`2d287f51eff2a5fbf84458a33f7fb2493cf67965`.
Object-embedding exceptions apply; no compiler/runtime source is bundled.

## Algorithm and compatibility facts

The new SHA-256 is ORIGINAL_PROJECT_CODE independently authored from FIPS PUB
180-4 algorithm definitions, not copied implementation text. Mathematical SHA
constants, addresses, lengths, BuildID and cryptographic fingerprints are facts.
The veneers are locally authored assembly and generated data. No BlueZ or
Fluoride implementation copy was established. Stock/vendor libbluetooth and
extracted instruction validation arrays are not distributed.

The system `libc.so`, `libdl.so`, `liblog.so`, `libm.so` are dynamic dependencies,
not bundled libraries. Android platform-tools and Magisk core are not bundled.
