#!/system/bin/sh
# New release transaction implementation. No vendor code is incorporated.
set -eu
action="$1"
tx="$2"
case "$tx" in *[!0-9TZabcdef-]*|'') echo BACKUP_MANIFEST_REJECTED; exit 1;; esac
base=/data/adb/ds3-fix
dir="$base/transactions/$tx"
bb=/data/adb/magisk/busybox
paths='data/misc/bluedroid/bt_config.conf data/misc/bluedroid/bt_config.bak data/adb/modules/ds3-hid-nosec data/adb/modules/ds3-uhid-hook'
case "$action" in
backup)
  mkdir -p "$base/transactions"
  mkdir "$base/install.lock" || { echo UNSAFE_STATE; exit 1; }
  mkdir "$dir" || exit 1
  chmod 700 "$base" "$dir"
  : > "$dir/present.txt"
  : > "$dir/absent.txt"
  : > "$dir/metadata.txt"
  : > "$dir/files.sha256"
  for p in $paths; do
    if [ -e "/$p" ]; then
      echo "$p" >> "$dir/present.txt"
      find "/$p" -exec stat -c '%a %u %g %n' '{}' \; >> "$dir/metadata.txt"
      ls -Zd "/$p" >> "$dir/metadata.txt"
      find "/$p" -type f -exec sha256sum '{}' \; >> "$dir/files.sha256"
    else echo "$p" >> "$dir/absent.txt"; fi
  done
  cd /
  "$bb" tar -cpf "$dir/state.tar" -T "$dir/present.txt"
  "$bb" tar -tf "$dir/state.tar" > "$dir/archive-list.txt"
  sha256sum "$dir/state.tar" > "$dir/state.sha256"
  sha256sum -c "$dir/state.sha256"
  # Extract independently and compare archived regular files before permitting commit.
  mkdir "$dir/verify"
  "$bb" tar -xpf "$dir/state.tar" -C "$dir/verify"
  while read -r hash path; do
    test "$(sha256sum "$dir/verify$path" | cut -d ' ' -f1)" = "$hash" || exit 1
  done < "$dir/files.sha256"
  rm -rf "$dir/verify"
  # Context manifest for every archived file, including module contents.
  : > "$dir/contexts.txt"
  for p in $paths; do
    if [ -e "/$p" ]; then find "/$p" -exec ls -Zd '{}' \; >> "$dir/contexts.txt"; fi
  done
  echo BACKUP_VERIFIED
  ;;
commit)
  test -f "$dir/manifest.json"
  sha256sum -c "$dir/state.sha256"
  test -d "$base/install.lock"
  # Framework airplane setting is not changed. Stop Bluetooth before replacing config.
  svc bluetooth disable
  n=0
  while pidof com.android.bluetooth >/dev/null; do
    n=$((n+1)); [ "$n" -le 30 ] || { echo BLUETOOTH_STOP_TIMEOUT; exit 1; }; sleep 1
  done
  conf=/data/misc/bluedroid/bt_config.conf
  test "$(sha256sum "$conf" | cut -d ' ' -f1)" = "$(cat "$dir/config-before.sha256")" || { echo CONFIG_RACE; exit 1; }
  test ! -e "$conf.ds3-new"
  cp -p "$conf" "$conf.ds3-new"
  cat "$dir/config-new.conf" > "$conf.ds3-new"
  chcon --reference="$conf" "$conf.ds3-new"
  sync
  mv -f "$conf.ds3-new" "$conf"
  for m in ds3-hid-nosec ds3-uhid-hook; do
    test -f "$dir/stage/$m/module.prop"
    rm -rf "/data/adb/modules/$m"
    cp -a "$dir/stage/$m" "/data/adb/modules/$m"
    chown -R 0:0 "/data/adb/modules/$m"
    find "/data/adb/modules/$m" -type d -exec chmod 755 '{}' \;
    find "/data/adb/modules/$m" -type f -exec chmod 644 '{}' \;
  done
  sha256sum -c "$dir/installed.sha256"
  # Keep adapter enabled for the one reboot and subsequent verification.
  svc bluetooth enable
  echo COMMITTED > "$dir/status"
  sync
  ;;
rollback)
  sha256sum -c "$dir/state.sha256"
  test -f "$dir/manifest.json"
  svc bluetooth disable
  n=0
  while pidof com.android.bluetooth >/dev/null; do
    n=$((n+1)); [ "$n" -le 30 ] || exit 1; sleep 1
  done
  for p in $paths; do rm -rf "/$p"; done
  cd /
  "$bb" tar -xpf "$dir/state.tar"
  sha256sum -c "$dir/files.sha256"
  # ls -Zd emits context then path on the pinned Android toolbox.
  while read -r context path; do
    case "$context" in u:object_r:*) chcon "$context" "$path";; *) echo CONTEXT_RESTORE_FAILED; exit 1;; esac
  done < "$dir/contexts.txt"
  rm -f /data/misc/bluedroid/bt_config.conf.ds3-new
  rm -rf "$base/install.lock"
  svc bluetooth enable
  sync
  echo ROLLBACK_RESTORED
  ;;
*) echo INVALID_ACTION; exit 1;;
esac
