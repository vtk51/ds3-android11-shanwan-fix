# Known issues

* LED indicators 1/2/3/4 can continue slowly blinking rather than showing player
  number. Cosmetic, non-blocking; no LED fix is included.
* One exact Android 11 ARM32 profile only. Not universal; no ARM64 support.
* Site B lowers the HID security attribute for incoming bonded HID generally.
* Existing proven address-specific bond admission is required. Automatic bond
  creation and USB master writing are not provided; master setup is `MANUAL_GATE`.
* Exact publication-safe rev7 payload is live-approved for the supported profile.
  This is not evidence for other firmware, controllers or architecture variants.
* Public installer/rollback have offline tests only. Archived live acceptance
  tested the production mechanism, not these newly written release transactions.
* Current profile requires Magisk 24.3/API v3 and the proven permissive environment;
  newer versions or enforcing SELinux need independent validation.
* ELF64 BuildID diagnostics require an external offline readelf.
