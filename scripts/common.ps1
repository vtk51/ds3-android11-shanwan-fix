Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:ReleaseRoot = Split-Path $PSScriptRoot -Parent
$script:Profile = Get-Content -LiteralPath (Join-Path $script:ReleaseRoot 'profiles/ohm-api30-arm32.json') -Raw | ConvertFrom-Json
$script:Adb = 'adb'
$script:Serial = ''
$script:Writes = 0
function Get-Sha([byte[]]$Bytes) {
    $h = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($h.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
    finally { $h.Dispose() }
}
function Get-Hex([byte[]]$Bytes, [int]$Offset, [int]$Count) {
    if ($Offset -lt 0 -or $Offset + $Count -gt $Bytes.Length) { throw 'UNSUPPORTED' }
    return ([BitConverter]::ToString($Bytes,$Offset,$Count)).Replace('-','').ToLowerInvariant()
}
function Assert-Library([byte[]]$Bytes, [switch]$Patched) {
    $l = $script:Profile.library
    $sha = if ($Patched) { $l.patchedSha256 } else { $l.stockSha256 }
    $site = if ($Patched) { $l.replacementSha256 } else { $l.originalSha256 }
    if ($Bytes.Length -ne $l.size -or (Get-Sha $Bytes) -ne $sha -or
        (Get-Hex $Bytes 0 5) -ne '7f454c4601' -or (Get-Hex $Bytes 18 2) -ne '2800' -or
        (Get-Hex $Bytes $l.buildIdOffset 16) -ne $l.buildId -or
        (Get-WindowSha $Bytes $l.siteBOffset $l.siteBLength) -ne $site) { throw 'UNSUPPORTED' }
    foreach ($s in $l.signatures) {
        if ((Get-WindowSha $Bytes $s.offset $s.length) -ne $s.sha256) { throw 'UNSUPPORTED' }
    }
}
function Get-WindowSha([byte[]]$Bytes, [int]$Offset, [int]$Count) {
    if ($Offset -lt 0 -or $Count -le 0 -or $Offset -gt $Bytes.Length - $Count) { throw 'UNSUPPORTED' }
    $h = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($h.ComputeHash($Bytes,$Offset,$Count))).Replace('-','').ToLowerInvariant() }
    finally { $h.Dispose() }
}
function Convert-Library([byte[]]$Bytes) {
    Assert-Library $Bytes
    [byte[]]$copy = $Bytes.Clone()
    $hex = $script:Profile.library.replacement
    for ($i=0; $i -lt 4; $i++) { $copy[$script:Profile.library.siteBOffset+$i] = [Convert]::ToByte($hex.Substring($i*2,2),16) }
    Assert-Library $copy -Patched
    return ,$copy
}
function Get-Classification($State) {
    $p = $script:Profile
    if ($State.api -ne $p.androidApi -or $State.fingerprint -cne $p.fingerprint -or
        $State.abi -cne $p.bluetoothAbi) { return 'UNSUPPORTED' }
    if (-not $State.root) { return 'UNSAFE_STATE' }
    if ($State.stockSha -ne $p.library.stockSha256 -or -not $State.binaryValid) { return 'UNSUPPORTED' }
    if (-not $State.root -or -not $State.magiskHealthy -or -not $State.zygisk -or
        $State.magiskVersion -ne $p.magiskVersionCode -or $State.selinux -ne $p.selinux -or
        $State.conflict -or -not $State.configSafe -or -not $State.bluetoothHealthy -or
        $State.visibleSha -notin @($p.library.stockSha256,$p.library.patchedSha256)) { return 'UNSAFE_STATE' }
    if ($State.hookSha -eq $p.hook.sha256 -and $State.visibleSha -eq $p.library.patchedSha256 -and $State.hidCanonical) { return 'ALREADY_INSTALLED' }
    return 'SUPPORTED'
}
function Invoke-Adb([string[]]$Arguments) {
    $prefix = @(); if ($script:Serial) { $prefix = @('-s',$script:Serial) }
    $out = & $script:Adb @prefix @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw ('ADB_FAILED: ' + ($out -join "`n")) }
    return ($out -join "`n").Trim()
}
function Get-RootCommand([string]$Command) { return "su -c '"+$Command.Replace("'","'\''")+"'" }
function Read-Device([string]$Command) { return Invoke-Adb @('shell',(Get-RootCommand $Command)) }
function Write-Device([string]$Command) {
    if ($script:DryRun) { throw 'DRYRUN_WRITE_REJECTED' }
    $script:Writes++
    return Read-Device $Command
}
function Read-DeviceBytes([string]$Path) {
    if ($Path -notmatch '^/[A-Za-z0-9_./-]+$') { throw 'INVALID_PATH' }
    return ,[Convert]::FromBase64String((Read-Device "base64 '$Path'"))
}
function Find-Controller([string]$Text) {
    $addresses = @()
    foreach ($m in [regex]::Matches($Text,'(?ms)^\[([0-9A-Fa-f:]{17})\]\s*\r?\n(.*?)(?=^\[|\z)')) {
        if ($m.Groups[2].Value -match '(?im)^Name\s*=\s*SHANWAN PS3 GamePad\s*$') { $addresses += $m.Groups[1].Value }
    }
    if ($addresses.Count -ne 1) { throw 'MANUAL_GATE: exactly one existing SHANWAN bond is required' }
    return $addresses[0]
}
function Convert-CachedHid([string]$Text, [string]$Address) {
    if ($Address -notmatch '^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$') { throw 'INVALID_BDADDR' }
    $sections = [regex]::Matches($Text,'(?ms)^\[([^\]\r\n]+)\][ \t]*\r?\n(.*?)(?=^\[|\z)')
    $selected = @($sections | Where-Object { $_.Groups[1].Value -ieq $Address })
    if ($selected.Count -ne 1) { throw 'UNSAFE_STATE: duplicate or missing controller section' }
    $m = $selected[0]; $body = $m.Groups[2].Value
    if ($body -notmatch '(?im)^LinkKeyType\s*=\s*4\s*$' -or $body -notmatch '(?im)^LinkKey\s*=\s*[0-9a-f]{32}\s*$') {
        throw 'MANUAL_GATE: existing proven bond admission is required'
    }
    $nl = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $body = [regex]::Replace($body,'(?im)^Hid(?:AttrMask|SubClass|AppId|VendorId|ProductId|Version|CountryCode|SSRMaxLatency|SSRMinTimeout|Descriptor)\s*=.*\r?\n?','')
    $body = $body.TrimEnd("`r","`n") + $nl
    foreach ($prop in $script:Profile.cachedHid.PSObject.Properties) { $body += $prop.Name + ' = ' + $prop.Value + $nl }
    $replacement = '[' + $m.Groups[1].Value + ']' + $nl + $body + $nl
    return $Text.Substring(0,$m.Index) + $replacement + $Text.Substring($m.Index+$m.Length)
}
function Assert-Payload {
    $path = Join-Path $script:ReleaseRoot 'payload/ds3-uhid-hook/zygisk/armeabi-v7a.so'
    if (-not $script:Profile.publication.ready -or -not (Test-Path -LiteralPath $path)) { throw 'PAYLOAD_MISSING_OR_UNLICENSED' }
    Assert-HookBytes ([IO.File]::ReadAllBytes($path))
}
function Assert-HookBytes([byte[]]$Bytes) {
    if ($Bytes.Length -ne $script:Profile.hook.size -or (Get-Sha $Bytes) -ne $script:Profile.hook.sha256 -or
        (Get-Hex $Bytes 0 6) -ne '7f454c460101' -or (Get-Hex $Bytes 18 2) -ne '2800') { throw 'PAYLOAD_CHECKSUM_REJECTED' }
}
function Test-InstallMarker([int]$Stage,[string]$Text,[string]$PidBt) {
    if ($Text -match '^armed') { return $false }
    $patterns=@('^sched pid=', '^entered pid=', '^map start=', '^target opened; size ok$',
        '^sha256=', '^sha256 matched pinned target$', '^rt out=', '^all 3 original signatures matched$',
        '^gap found veneer=', '^veneer rx; literals patched; icache flushed$', '^transaction begin$',
        '^all 3 writes verified in place$', '^cache flush completed \(all sites\)$', '^transaction committed; hooks live$')
    if($Stage -lt 0 -or $Stage -gt 13 -or $Text -notmatch $patterns[$Stage]) { return $false }
    if($Stage -le 1 -and $Text -notmatch ("pid="+[regex]::Escape($PidBt)+'\b')) { return $false }
    return $true
}
function Get-Plan([string]$Classification, [bool]$DryRun) {
    if ($Classification -notin @('SUPPORTED','ALREADY_INSTALLED')) { throw $Classification }
    if ($Classification -eq 'ALREADY_INSTALLED') { return @('verify only; no reboot') }
    return @('verified timestamped backup','MANUAL_GATE: master BDADDR readback','atomic cached HID merge',
        'device-derived Site B Magisk overlay','pinned publication-safe production rev7 module','on-device checksums',
        'exactly one normal reboot','ADB/root and Magic Mount verification','STG0-STG5 and I00-I13',
        'Bluetooth health','one P3 and SHANWAN inputs','optional bounded Cross test')
}
function Get-Manifest([string]$Transaction, $State, $Entries) {
    return [ordered]@{schemaVersion=1; transaction=$Transaction; version='1.0.0'; profile=$script:Profile.id;
        createdUtc=[DateTime]::UtcNow.ToString('o'); stockSha256=$State.stockSha;
        stockBuildId=$script:Profile.library.buildId; entries=@($Entries); status='BACKUP_VERIFIED';
        createdPaths=@("/data/adb/ds3-fix/transactions/$Transaction",'/data/adb/ds3-fix/install.lock')}
}
function Get-RollbackPlan($Manifest) {
    if ($Manifest.schemaVersion -ne 1 -or $Manifest.transaction -notmatch '^\d{8}T\d{6}Z-[a-f0-9]{8}$' -or
        $Manifest.profile -ne $script:Profile.id) { throw 'BACKUP_MANIFEST_REJECTED' }
    return @($Manifest.entries | ForEach-Object { if ($_.existed) { 'restore ' + $_.path } else { 'remove ' + $_.path } })
}
function Get-State {
    $api = Invoke-Adb @('shell','getprop','ro.build.version.sdk')
    $fp = Invoke-Adb @('shell','getprop','ro.build.fingerprint')
    $abi = Invoke-Adb @('shell','getprop','ro.product.cpu.abi')
    $s = [ordered]@{api=$api;fingerprint=$fp;abi=$abi;root=$false;stockSha='';binaryValid=$false;
        magiskHealthy=$false;zygisk=$false;magiskVersion=0;selinux='';conflict=$false;configSafe=$false;
        hookSha='';visibleSha='';hidCanonical=$false;stockPath='';controller='';config='';configBytes=$null;boxMac='';
        bluetoothHealthy=$false;magiskFailure=''}
    if ($api -ne $script:Profile.androidApi -or $fp -cne $script:Profile.fingerprint -or $abi -cne $script:Profile.bluetoothAbi) { return [pscustomobject]$s }
    try { $s.root = (Read-Device 'id -u') -eq '0' } catch { return [pscustomobject]$s }
    if (-not $s.root) { return [pscustomobject]$s }
    $s.magiskVersion = Read-Device 'magisk -V'
    $s.selinux = Read-Device 'getenforce'
    $mp = Read-Device 'magisk --path'
    if ($mp -notmatch '^/[A-Za-z0-9_./-]+$') { return [pscustomobject]$s }
    $s.stockPath = "$mp/.magisk/mirror/system/lib/libbluetooth.so"
    try {
        $stock = Read-DeviceBytes $s.stockPath
        $s.stockSha = Get-Sha $stock
        Assert-Library $stock
        $pidBt = Read-Device 'pidof com.android.bluetooth'
        if ($pidBt -notmatch '^\d+$') { throw 'BLUETOOTH_PROCESS_MISSING' }
        $maps = Read-Device "cat /proc/$pidBt/maps"
        if ($maps -notmatch '/system/lib/libbluetooth\.so' -or $maps -match '/system/lib64/libbluetooth\.so') { throw 'UNSUPPORTED' }
        $exe = Read-Device "readlink /proc/$pidBt/exe"
        $exeBytes = Read-DeviceBytes $exe
        if ((Get-Hex $exeBytes 0 5) -ne '7f454c4601') { throw 'UNSUPPORTED' }
        $s.binaryValid = $true
    } catch { return [pscustomobject]$s }
    $s.visibleSha = (Read-Device 'sha256sum /system/lib/libbluetooth.so').Split(' ')[0]
    $s.magiskHealthy = (Read-Device 'if test -x /data/adb/magisk/busybox && /data/adb/magisk/busybox true; then echo OK; else echo BROKEN; fi') -eq 'OK'
    if(-not $s.magiskHealthy) {
        $signature=Read-Device 'if test -f /cache/magisk.log; then grep -F "Magisk environment incomplete, abort" /cache/magisk.log || true; fi'
        $empty=Read-Device 'if test -d /data/adb/magisk && test -z "$(ls -A /data/adb/magisk)"; then echo EMPTY; fi'
        $source=Read-Device 'if test -f /data/app/Magisk/lib/arm/libbusybox.so; then sha256sum /data/app/Magisk/lib/arm/libbusybox.so; fi'
        if($s.magiskVersion -eq 24300 -and $signature -match 'Magisk environment incomplete, abort' -and $empty -eq 'EMPTY' -and
            $source.StartsWith('8365306415d5461f9a7b4bc28c7a90697150a002d28d5cdf43b361640eeca687')) {
            $s.magiskFailure='MAGISK_24300_DATABIN_MANUAL_REPAIR_REQUIRED: see docs/TROUBLESHOOTING.md; no automatic repair'
        } else { $s.magiskFailure='MAGISK_ENVIRONMENT_UNHEALTHY: restore a working Magisk environment; no historical repair authorized' }
    }
    $health=Read-Device 'dumpsys bluetooth_manager'
    $s.bluetoothHealthy=$health -match 'state: ON' -and $health -match 'Bluetooth crashed 0 times'
    $z = Read-Device 'magisk --sqlite ''SELECT value FROM settings WHERE key="zygisk";'''
    $s.zygisk = $z -match 'value=1'
    $s.conflict = (Read-Device 'if test ! -e /data/adb/modules_update/ds3-hid-nosec && test ! -e /data/adb/modules_update/ds3-uhid-hook && test ! -e /data/adb/ds3-fix/install.lock && test ! -e /data/adb/modules/ds3-hid-nosec/disable && test ! -e /data/adb/modules/ds3-hid-nosec/remove && test ! -e /data/adb/modules/ds3-uhid-hook/disable && test ! -e /data/adb/modules/ds3-uhid-hook/remove; then echo OK; fi') -ne 'OK'
    try { $s.hookSha = (Read-Device 'if test -f /data/adb/modules/ds3-uhid-hook/zygisk/armeabi-v7a.so; then sha256sum /data/adb/modules/ds3-uhid-hook/zygisk/armeabi-v7a.so; fi').Split(' ')[0] } catch { }
    try {
        $s.configBytes = Read-DeviceBytes '/data/misc/bluedroid/bt_config.conf'
        $s.config = [Text.Encoding]::UTF8.GetString($s.configBytes)
        $s.controller = Find-Controller $s.config
        $converted = Convert-CachedHid $s.config $s.controller
        $s.hidCanonical = $converted -ceq $s.config
        $s.boxMac = ([regex]::Match($s.config,'(?ms)^\[Adapter\]\s*\n(?:(?!^\[).)*?^Address\s*=\s*((?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2})')).Groups[1].Value
        $s.configSafe = $s.boxMac.Length -eq 17
    } catch { $s.configSafe = $false }
    return [pscustomobject]$s
}
