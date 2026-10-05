[CmdletBinding()]
param([switch]$DryRun, [string]$Adb='adb', [string]$Serial='', [switch]$CrossTest)
. "$PSScriptRoot/common.ps1"
$script:Adb=$Adb; $script:Serial=$Serial; $script:DryRun=[bool]$DryRun
$state=Get-State
$classification=Get-Classification $state
$classification
if($state.magiskFailure) { $state.magiskFailure }
$plan=Get-Plan $classification ([bool]$DryRun)
$plan
if ($DryRun) {
    if (-not $script:Profile.publication.ready) { 'BLOCKED: PAYLOAD_MISSING_OR_UNLICENSED' }
    if ($script:Writes -ne 0) { throw 'DRYRUN_WRITE_REJECTED' }
    return
}
if ($classification -eq 'ALREADY_INSTALLED') { & "$PSScriptRoot/verify.ps1" -Adb $Adb -Serial $Serial; return }
Assert-Payload
# Manual USB pairing uses no bundled, unproven USB writer.
"MANUAL_GATE: box Bluetooth MAC $($state.boxMac); controller $($state.controller); USB VID:PID 054c:0268"
$answer=Read-Host 'Confirm independent USB master BDADDR readback equals box Bluetooth MAC; enter that MAC'
if ($answer -ine $state.boxMac) { throw 'MANUAL_GATE' }
$tx=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$remote="/data/adb/ds3-fix/transactions/$tx"
$local=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) "DS3Fix/backups/$tx"
$null=New-Item -ItemType Directory -Path $local
function Push-Verified([string]$LocalPath,[string]$RemotePath) {
    if ($script:DryRun) { throw 'DRYRUN_WRITE_REJECTED' }
    $script:Writes++
    $null=Invoke-Adb @('push',$LocalPath,$RemotePath)
    $hash=(Get-FileHash -LiteralPath $LocalPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ((Read-Device "sha256sum '$RemotePath'").Split(' ')[0] -ne $hash) { throw 'PUSH_CHECKSUM_FAILED' }
}
$shell=[IO.File]::ReadAllText("$PSScriptRoot/transaction.sh").Replace("`r`n","`n")
# Streaming backup script avoids creating helper state outside the transaction.
$backupCmd="sh -c '"+$shell.Replace("'","'\''")+"' -- backup '$tx'"
if ((Write-Device $backupCmd) -notmatch 'BACKUP_VERIFIED') { throw 'BACKUP_VERIFICATION_FAILED' }
$entries=@()
$paths=@('/data/misc/bluedroid/bt_config.conf','/data/misc/bluedroid/bt_config.bak','/data/adb/modules/ds3-hid-nosec','/data/adb/modules/ds3-uhid-hook')
foreach ($path in $paths) {
    $exists=(Read-Device "if test -e '$path'; then echo YES; else echo NO; fi") -eq 'YES'
    $entries += [ordered]@{path=$path;existed=$exists;metadata=if($exists){Read-Device "stat -c '%a %u %g' '$path'; ls -Zd '$path'"}else{''}}
}
$null=Invoke-Adb @('pull',"$remote/state.tar",(Join-Path $local 'state.tar'))
$archiveHash=(Get-FileHash (Join-Path $local 'state.tar') -Algorithm SHA256).Hash.ToLowerInvariant()
if ((Read-Device "sha256sum '$remote/state.tar'").Split(' ')[0] -ne $archiveHash) { throw 'BACKUP_VERIFICATION_FAILED' }
foreach ($file in @('metadata.txt','contexts.txt','present.txt','absent.txt','archive-list.txt','files.sha256')) { $null=Invoke-Adb @('pull',"$remote/$file",(Join-Path $local $file)) }
$manifest=Get-Manifest $tx $state $entries
$manifest.archiveSha256=$archiveHash
$manifest.fileHashes=[IO.File]::ReadAllText((Join-Path $local 'files.sha256'))
$original=Read-DeviceBytes $state.stockPath
Assert-Library $original
[IO.File]::WriteAllBytes((Join-Path $local 'stock-libbluetooth.original'),$original)
Push-Verified (Join-Path $local 'stock-libbluetooth.original') "$remote/stock-libbluetooth.original"
$manifest.stockBackupSha256=Get-Sha $original
$utf8=New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $local 'manifest.json'),($manifest | ConvertTo-Json -Depth 10),$utf8)
Push-Verified (Join-Path $local 'manifest.json') "$remote/manifest.json"
[IO.File]::WriteAllText((Join-Path $local 'transaction.sh'),$shell,$utf8)
Push-Verified (Join-Path $local 'transaction.sh') "$remote/transaction.sh"
$changed=Convert-CachedHid $state.config $state.controller
[IO.File]::WriteAllText((Join-Path $local 'config-new.conf'),$changed,$utf8)
[IO.File]::WriteAllText((Join-Path $local 'config-before.sha256'),(Get-Sha $state.configBytes),$utf8)
Push-Verified (Join-Path $local 'config-new.conf') "$remote/config-new.conf"
Push-Verified (Join-Path $local 'config-before.sha256') "$remote/config-before.sha256"
# Read the user's unmodified mirror, transform locally, pin the exact resulting hash.
$patched=Convert-Library $original
$generated=Join-Path $local 'libbluetooth.transformed'
[IO.File]::WriteAllBytes($generated,$patched)
$null=Write-Device "mkdir -p '$remote/stage/ds3-hid-nosec/system/lib' '$remote/stage/ds3-uhid-hook/zygisk'"
Push-Verified $generated "$remote/stage/ds3-hid-nosec/system/lib/libbluetooth.so"
Push-Verified (Join-Path $script:ReleaseRoot 'payload/ds3-uhid-hook/zygisk/armeabi-v7a.so') "$remote/stage/ds3-uhid-hook/zygisk/armeabi-v7a.so"
foreach($module in @('ds3-hid-nosec','ds3-uhid-hook')) { Push-Verified (Join-Path $script:ReleaseRoot "payload/$module/module.prop") "$remote/stage/$module/module.prop" }
$checks=$script:Profile.library.patchedSha256+'  /data/adb/modules/ds3-hid-nosec/system/lib/libbluetooth.so'+"`n"+
    $script:Profile.hook.sha256+'  /data/adb/modules/ds3-uhid-hook/zygisk/armeabi-v7a.so'+"`n"+
    (Get-Sha ([Text.Encoding]::UTF8.GetBytes($changed)))+'  /data/misc/bluedroid/bt_config.conf'+"`n"
[IO.File]::WriteAllText((Join-Path $local 'installed.sha256'),$checks,$utf8)
Push-Verified (Join-Path $local 'installed.sha256') "$remote/installed.sha256"
[IO.File]::WriteAllText((Join-Path $local 'transaction.sh'),$shell,$utf8)
Push-Verified (Join-Path $local 'transaction.sh') "$remote/transaction.sh"
$null=Write-Device "sh '$remote/transaction.sh' commit '$tx'"
'Backup transaction: '+$tx
# Exactly one reboot; failures never trigger a recovery reboot or automatic retry.
$null=Invoke-Adb @('reboot')
$deadline=[DateTime]::UtcNow.AddMinutes(5)
do {
    Start-Sleep 3
    try { $ready=(Read-Device 'getprop sys.boot_completed; id -u') -match '1\s+0'; } catch { $ready=$false }
} until ($ready -or [DateTime]::UtcNow -gt $deadline)
if (-not $ready) { throw 'ADB_ROOT_WAIT_TIMEOUT' }
& "$PSScriptRoot/verify.ps1" -Adb $Adb -Serial $Serial -AskP3 -CrossTest:$CrossTest
$null=Write-Device 'rmdir /data/adb/ds3-fix/install.lock'
'INSTALL_PASS'
