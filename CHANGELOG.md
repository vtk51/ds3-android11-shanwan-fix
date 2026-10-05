# Changelog

## 1.0.0

* Exact Android 11 ARM32 firmware profile and fail-closed classification.
* Device-derived four-byte Site B transform with exact before/after pins.
* Backup-first cached HID merge, manual USB master gate, transactional installer,
  selected-transaction rollback and minimal firmware diagnostics.
* English/Russian documentation, offline checks and device-free CI.
* Included the exact live-approved publication-safe rev7 production payload:
  `e4183947d3ef3917b4b8cc261b3a869e6190aedcd59c87728b24061a578447cf`.
* Retained independent project SHA-256 and per-site digest validation; excluded
  old unknown SHA implementation and extracted vendor validation arrays.
* Corrected original OUTPUT/SET call-sites to BL, preserving LR semantics;
  completion RSP remains B.W. This is not a claimed player-LED fix.
* Added native SHA/fingerprint tests, normalized equivalence, vendor-data scan
  and complete known permissive notices. Exact-binary controlled P3/sony_probe,
  input/Cross press-release and Bluetooth health live acceptance PASS.
* Final offline packaging includes approved payload only; installer payload
  gate enabled. Internal checksums, publishable offline checks and clean ZIP
  extraction tests required. GitHub publication remains a separate operation.
* LED 1–4 blinking remains a known cosmetic issue.
