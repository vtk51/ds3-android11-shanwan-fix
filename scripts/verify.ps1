[CmdletBinding()]
param([string]$Adb='adb', [string]$Serial='', [switch]$AskP3, [switch]$CrossTest)
. "$PSScriptRoot/common.ps1"
$script:Adb=$Adb; $script:Serial=$Serial
if ((Read-Device 'id -u') -ne '0' -or (Read-Device 'magisk -V') -ne '24300') { throw 'UNSAFE_STATE' }
if ((Read-Device 'magisk --sqlite ''SELECT value FROM settings WHERE key="zygisk";''') -notmatch 'value=1') { throw 'ZYGISK_DISABLED' }
$pidBt=Read-Device 'pidof com.android.bluetooth'
if($pidBt -notmatch '^\d+$') { throw 'BLUETOOTH_PROCESS_MISSING' }
Assert-Library (Read-DeviceBytes '/system/lib/libbluetooth.so') -Patched
$maps=Read-Device "cat /proc/$pidBt/maps"
if($maps -notmatch '(?m)^.*r-xp.*libbluetooth\.so' -or $maps -notmatch '(?m)r-xp 00001000.* /memfd:jit-cache \(deleted\)') { throw 'MAGIC_MOUNT_OR_ZYGISK_MAPPING_FAILED' }
if((Read-Device "cat /proc/$pidBt/mountinfo") -notmatch ' /system/lib/libbluetooth\.so ') { throw 'MAGIC_MOUNT_FAILED' }
if ((Read-Device 'sha256sum /data/adb/modules/ds3-uhid-hook/zygisk/armeabi-v7a.so').Split(' ')[0] -ne $script:Profile.hook.sha256) { throw 'PAYLOAD_CHECKSUM_REJECTED' }
$names=@('stg0_ctor','stg1_entry','stg2_onload','stg3_preapp','stg4_btmatch','stg5_install')
foreach($name in $names) {
    $text=Read-Device "cat /data/local/tmp/ds3_uhid_$name"
    if($text -notmatch 'pid=\d+') { throw "STAGE_FAILED: $name" }
    # STG0-STG3 can be overwritten by later zygote children; use boot-age metadata.
    $age=[long](Read-Device "stat -c %Y /data/local/tmp/ds3_uhid_$name")
    $now=[long](Read-Device 'date +%s'); $uptime=[double](Read-Device "cut -d ' ' -f1 /proc/uptime")
    if($age -lt ($now-$uptime-2)) { throw "STALE_STAGE: $name" }
    if($name -in @('stg4_btmatch','stg5_install') -and $text -notmatch "pid=$pidBt\b") { throw "WRONG_PID: $name" }
}
for($i=0;$i -le 13;$i++) {
    $name='I'+$i.ToString('00')
    $path="/data/adb/modules/ds3-uhid-hook/$name"
    $text=Read-Device "if test -f '$path'; then cat '$path'; fi"
    if(-not (Test-InstallMarker $i $text $pidBt)) {
        $path="/data/local/tmp/$name"
        $text=Read-Device "cat '$path'"
    }
    if(-not (Test-InstallMarker $i $text $pidBt)) { throw "STAGE_FAILED: $name" }
    $age=[long](Read-Device "stat -c %Y '$path'")
    $now=[long](Read-Device 'date +%s'); $uptime=[double](Read-Device "cut -d ' ' -f1 /proc/uptime")
    if($age -lt ($now-$uptime-2)) { throw "STALE_STAGE: $name" }
}
$health=Read-Device 'dumpsys bluetooth_manager'
if($health -notmatch 'state: ON' -or $health -notmatch 'Bluetooth crashed 0 times') { throw 'BLUETOOTH_UNHEALTHY' }
if($AskP3) { $null=Read-Host 'Press P3/PS once, then press Enter' }
$inputs=Read-Device 'cat /proc/bus/input/devices'
$blocks=@($inputs -split '(?:\r?\n){2,}' | Where-Object { $_ -match 'Name="SHANWAN PS3 GamePad"' -and $_ -match 'Bus=0005 Vendor=054c Product=0268' })
if($blocks.Count -ne 1 -or $inputs -notmatch 'SHANWAN PS3 GamePad Motion Sensors') { throw 'SHANWAN_INPUT_MISSING' }
$node=[regex]::Match($blocks[0],'\bevent\d+\b').Value
if(-not $node) { throw 'SHANWAN_INPUT_MISSING' }
if($CrossTest) {
    'Press and release Cross once during the next 30 seconds.'
    $events=Read-Device "timeout 30 getevent -lt /dev/input/$node; rc=`$?; test `$rc -eq 0 -o `$rc -eq 124"
    if($events -notmatch 'EV_KEY\s+(BTN_GAMEPAD|BTN_SOUTH)\s+DOWN' -or $events -notmatch 'EV_KEY\s+(BTN_GAMEPAD|BTN_SOUTH)\s+UP') { throw 'CROSS_ACCEPTANCE_FAILED' }
}
if((Read-Device 'pidof com.android.bluetooth') -ne $pidBt) { throw 'BLUETOOTH_RESTARTED' }
$health=Read-Device 'dumpsys bluetooth_manager'
if($health -notmatch 'Bluetooth crashed 0 times' -or $health -notmatch 'state: ON') { throw 'BLUETOOTH_UNHEALTHY' }
'VERIFY_PASS: Magic Mount, Zygisk, STG0-STG5, I00-I13, Bluetooth and SHANWAN input'
