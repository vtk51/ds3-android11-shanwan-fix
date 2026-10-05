[CmdletBinding()]
param([switch]$RequirePublishable)
. "$PSScriptRoot/../scripts/common.ps1"
$script:Pass=0
function Check([string]$Name,[scriptblock]$Body) {
    & $Body
    $script:Pass++
    'PASS: '+$Name
}
function Assert([bool]$Value,[string]$Message='ASSERTION_FAILED') { if(-not $Value) { throw $Message } }
function Reject([scriptblock]$Body,[string]$Pattern='.*') {
    $failed=$false
    try { & $Body | Out-Null } catch { $failed=$true; Assert ($_.Exception.Message -match $Pattern) }
    Assert $failed 'EXPECTED_REJECTION'
}
function Fixture {
    return [pscustomobject]@{api=30;fingerprint=$script:Profile.fingerprint;abi='armeabi-v7a';root=$true;
        stockSha=$script:Profile.library.stockSha256;binaryValid=$true;magiskHealthy=$true;
        zygisk=$true;magiskVersion=24300;selinux='Permissive';conflict=$false;configSafe=$true;
        hookSha='';visibleSha=$script:Profile.library.stockSha256;hidCanonical=$false;bluetoothHealthy=$true;magiskFailure='';boxMac='';controller=''}
}
Check 'PowerShell syntax: every shipped script' {
    foreach($f in Get-ChildItem $script:ReleaseRoot -Recurse -File -Filter '*.ps1') {
        $tokens=$null;$errors=$null
        $null=[Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$tokens,[ref]$errors)
        Assert ($errors.Count -eq 0) ($f.Name+': '+($errors -join '; '))
    }
}
Check 'profile/schema and immutable evidence' {
    $p=$script:Profile
    foreach($key in @('schemaVersion','id','androidApi','fingerprint','bluetoothAbi','magiskVersionCode','zygiskApi','selinux','library','hook','cachedHid','masterBdaddr','publication')) { Assert ($null -ne $p.PSObject.Properties[$key]) }
    Assert ($p.schemaVersion -eq 1 -and $p.androidApi -eq 30 -and $p.bluetoothAbi -ceq 'armeabi-v7a')
    Assert ($p.magiskVersionCode -eq 24300 -and $p.zygiskApi -eq 3 -and $p.masterBdaddr -eq 'MANUAL_GATE')
    Assert ($p.library.path -ceq '/system/lib/libbluetooth.so' -and $p.library.size -eq 4138248)
    Assert ($p.library.stockSha256 -ceq '153cb547688608e4070276e1f688d37a8eecb9146c491a34e3d5e793f7763caa')
    Assert ($p.library.patchedSha256 -ceq '68249b8126a3160fdf17a93b464762d8517cea2d25c125aacb4fddb47fddb86c')
    Assert ($p.library.buildId -ceq 'bc23b5e2a1463ef9218d6318663d54be' -and $p.library.buildIdOffset -eq 0x19c)
    Assert ($p.library.siteBOffset -eq 0x20769a -and $p.library.siteBLength -eq 4 -and $p.library.originalSha256 -cmatch '^[0-9a-f]{64}$' -and $p.library.replacement -ceq '4ff00101')
    Assert ($null -eq $p.library.PSObject.Properties['original'])
    foreach($s in $p.library.signatures) { Assert ($s.sha256 -cmatch '^[0-9a-f]{64}$' -and $s.offset -gt 0 -and $s.length -in @(4,26) -and $s.offset+$s.length -lt $p.library.size -and $null -eq $s.PSObject.Properties['hex']) }
    Assert ($p.library.signatures.Count -eq 3)
    Assert ($p.hook.sha256 -ceq 'e4183947d3ef3917b4b8cc261b3a869e6190aedcd59c87728b24061a578447cf' -and $p.hook.size -gt 0)
    Assert ($p.publication.ready -and $p.publication.blocker -ceq 'NONE')
    Assert ($p.publication.approval -ceq 'PRODUCTION_APPROVED_PUBLICATION_SAFE_REV7' -and $p.publication.liveAcceptance -ceq 'PASS')
    Assert (@($p.cachedHid.PSObject.Properties).Count -eq 10)
    Assert ($p.cachedHid.HidAppId -eq '6' -and $p.cachedHid.HidAttrMask -eq '117')
    Assert ($p.cachedHid.HidDescriptor -cmatch '^[0-9a-f]{296}$')
}
Check 'known exact profile -> SUPPORTED' { Assert ((Get-Classification (Fixture)) -ceq 'SUPPORTED') }
Check 'ADB root command retains one quoted shell argument and escapes nested quotes' {
    Assert ((Get-RootCommand 'id -u') -ceq "su -c 'id -u'")
    Assert ((Get-RootCommand "echo 'test'") -ceq "su -c 'echo '\''test'\'''" )
}
Check 'wrong stock SHA -> UNSUPPORTED' { $s=Fixture;$s.stockSha='0'*64;Assert ((Get-Classification $s) -ceq 'UNSUPPORTED') }
Check 'wrong ABI -> UNSUPPORTED' { $s=Fixture;$s.abi='arm64-v8a';Assert ((Get-Classification $s) -ceq 'UNSUPPORTED') }
Check 'wrong fingerprint/API/BuildID validation -> UNSUPPORTED' {
    $s=Fixture;$s.fingerprint='unknown';Assert ((Get-Classification $s) -ceq 'UNSUPPORTED')
    $s=Fixture;$s.api=31;Assert ((Get-Classification $s) -ceq 'UNSUPPORTED')
    $s=Fixture;$s.binaryValid=$false;Assert ((Get-Classification $s) -ceq 'UNSUPPORTED')
}
Check 'missing root -> UNSAFE_STATE' { $s=Fixture;$s.root=$false;Assert ((Get-Classification $s) -ceq 'UNSAFE_STATE') }
Check 'unknown Magisk and unhealthy state never receive repair' {
    $s=Fixture;$s.magiskVersion=27000;Assert ((Get-Classification $s) -ceq 'UNSAFE_STATE')
    $s=Fixture;$s.magiskHealthy=$false;Assert ((Get-Classification $s) -ceq 'UNSAFE_STATE')
    $s=Fixture;$s.bluetoothHealthy=$false;Assert ((Get-Classification $s) -ceq 'UNSAFE_STATE')
    $s=Fixture;$s.conflict=$true;Assert ((Get-Classification $s) -ceq 'UNSAFE_STATE')
    $s=Fixture;$s.visibleSha='0'*64;Assert ((Get-Classification $s) -ceq 'UNSAFE_STATE')
}
Check 'already installed -> ALREADY_INSTALLED' {
    $s=Fixture;$s.hookSha=$script:Profile.hook.sha256;$s.visibleSha=$script:Profile.library.patchedSha256;$s.hidCanonical=$true
    Assert ((Get-Classification $s) -ceq 'ALREADY_INSTALLED')
}
# Execute the actual installer body with only its common import replaced by this
# test scope. Read-only observation is mocked; every write/external call is a spy.
$installer=[IO.File]::ReadAllText((Join-Path $script:ReleaseRoot 'scripts/install.ps1'))
$installer=$installer.Replace('. "$PSScriptRoot/common.ps1"','')
$installerBlock=[scriptblock]::Create($installer)
function Invoke-Adb([string[]]$Arguments) { throw 'UNEXPECTED_ADB_CALL' }
function Read-Device([string]$Command) { throw 'UNEXPECTED_DEVICE_CALL' }
function Get-State { return $script:Observation }
Check 'unknown firmware cannot reach mutation stage: actual installer' {
    $script:Observation=Fixture;$script:Observation.fingerprint='unknown'
    $script:Writes=0
    Reject { & $installerBlock } 'UNSUPPORTED'
    Assert ($script:Writes -eq 0)
}
Check 'DryRun performs zero host/device writes: actual installer' {
    $script:Observation=Fixture;$script:Writes=0
    $filesBefore=@(Get-ChildItem $script:ReleaseRoot -Recurse -File | ForEach-Object { $_.FullName+':'+(Get-FileHash $_.FullName).Hash })
    & $installerBlock -DryRun | Out-Null
    $filesAfter=@(Get-ChildItem $script:ReleaseRoot -Recurse -File | ForEach-Object { $_.FullName+':'+(Get-FileHash $_.FullName).Hash })
    Assert ($script:Writes -eq 0 -and ($filesBefore -join "`n") -ceq ($filesAfter -join "`n"))
}
Check 'unapproved publication state blocks actual installer before any writes' {
    $script:Observation=Fixture;$script:Writes=0
    $ready=$script:Profile.publication.ready
    try {
        $script:Profile.publication.ready=$false
        Reject { & $installerBlock } 'PAYLOAD_MISSING_OR_UNLICENSED'
        Assert ($script:Writes -eq 0)
    } finally { $script:Profile.publication.ready=$ready }
}
Check 'approved payload unlocks actual installer up to manual gate with zero writes' {
    $script:Observation=Fixture;$script:Writes=0
    function Read-Host([string]$Prompt) { throw 'OFFLINE_MANUAL_GATE_REACHED' }
    Reject { & $installerBlock } 'OFFLINE_MANUAL_GATE_REACHED'
    Assert ($script:Writes -eq 0)
}
# Synthetic protocol address constructed at runtime; no development identifiers.
$address=(@('02','00','00','00','00','01') -join ':')
$bond='[Adapter]'+"`n"+'Other = keep'+"`n`n"+'['+$address+']'+"`n"+'Name = SHANWAN PS3 GamePad'+"`n"+'LinkKeyType = 4'+"`n"+'LinkKey = '+('0'*32)+"`n"+'Unrelated = keep'+"`n`n"
Check 'cached HID transformation idempotent and dynamically selected' {
    Assert ((Find-Controller $bond) -ceq $address)
    $first=Convert-CachedHid $bond $address
    $second=Convert-CachedHid $first $address
    Assert ($first -ceq $second)
    Assert ($first.Contains('Unrelated = keep') -and $first.Contains('LinkKeyType = 4'))
    Assert ([regex]::Matches($first,'(?m)^HidAppId = 6$').Count -eq 1)
    Assert ([regex]::Matches($first,'(?m)^HidAttrMask = 117$').Count -eq 1)
    Assert ([regex]::Matches($first,'(?m)^\['+[regex]::Escape($address)+'\]$').Count -eq 1)
}
Check 'duplicate HID keys collapsed; duplicate sections rejected' {
    $text=$bond+'HidAppId = 1'+"`n"+'HidAppId = 2'+"`n"
    $new=Convert-CachedHid $text $address
    Assert ([regex]::Matches($new,'(?m)^HidAppId\s*=').Count -eq 1)
    Reject { Convert-CachedHid ($bond+'['+$address+']'+"`n") $address } 'UNSAFE_STATE'
}
Check 'ambiguous controller and absent admission rejected' {
    Reject { Find-Controller '[Adapter]' } 'MANUAL_GATE'
    Reject { Convert-CachedHid ($bond.Replace('LinkKeyType = 4','LinkKeyType = 0')) $address } 'MANUAL_GATE'
}
Check 'backup manifest generation and rollback plan' {
    $entries=@([pscustomobject]@{path='/data/misc/bluedroid/bt_config.conf';existed=$true;metadata='660 1002 1002'},
        [pscustomobject]@{path='/data/adb/modules/ds3-uhid-hook';existed=$false;metadata=''})
    $m=Get-Manifest '20261004T000000Z-abcdef01' (Fixture) $entries
    Assert ($m.status -eq 'BACKUP_VERIFIED' -and $m.stockSha256 -eq $script:Profile.library.stockSha256)
    $roundTrip=($m | ConvertTo-Json -Depth 8 | ConvertFrom-Json)
    $plan=Get-RollbackPlan $roundTrip
    Assert ($plan.Count -eq 2 -and $plan[0] -eq 'restore /data/misc/bluedroid/bt_config.conf' -and $plan[1] -eq 'remove /data/adb/modules/ds3-uhid-hook')
    $roundTrip.transaction='../escape';Reject { Get-RollbackPlan $roundTrip } 'BACKUP_MANIFEST_REJECTED'
}
Check 'only approved rev7 checksum selected; all old/diagnostic identities rejected' {
    foreach($hash in @('02d11435c1e01b78b7bd80791dad7191cc299149be92d8245966219c3157d706',
        'ad9d54f059f28680cdc4257cd14f132ff655ddf320690bcb4cffca6430be2221',
        '6da7e5475f812e445f67dc91ed59a585d8f1898c3d3bf419456a0fbae6523833',
        '772652374dcf92a5abfc92adf905f6bd2c92137c710de1fbd0494bc29c741417',
        '80fa3e9b4c0f1f02ccb87c144a94b2a3bda18d297d371aebae66e3de2fe5f32c',
        '2fcc200075b24a216129646d4e586398c1da3de8b37d24a21937198a47e2f9d4')) { Assert ($hash -ne $script:Profile.hook.sha256) }
    foreach($f in Get-ChildItem (Join-Path $script:ReleaseRoot 'payload') -Recurse -File -Filter '*.so') { Assert ((Get-FileHash $f.FullName).Hash.ToLowerInvariant() -eq $script:Profile.hook.sha256) }
    Reject { Assert-HookBytes ([Text.Encoding]::UTF8.GetBytes('diagnostic trace2')) } 'PAYLOAD_CHECKSUM_REJECTED'
    Reject { Assert-HookBytes (New-Object byte[] $script:Profile.hook.size) } 'PAYLOAD_CHECKSUM_REJECTED'
    if(-not $script:Profile.publication.ready) { Reject { Assert-Payload } 'PAYLOAD_MISSING_OR_UNLICENSED' }
}
Check 'local transform fails closed on synthetic/wrong stock' {
    Reject { Convert-Library ([byte[]]@(127,69,76,70,1)) } 'UNSUPPORTED'
    [byte[]]$large=New-Object byte[] $script:Profile.library.size
    Reject { Convert-Library $large } 'UNSUPPORTED'
}
Check 'backup-first atomic/context-preserving transaction invariants' {
    $sh=[IO.File]::ReadAllText((Join-Path $script:ReleaseRoot 'scripts/transaction.sh'))
    Assert ($sh.Contains('tar -cpf') -and $sh.Contains('tar -xpf') -and $sh.Contains('files.sha256') -and $sh.Contains('contexts.txt'))
    Assert ($sh.Contains('chcon --reference=') -and $sh.Contains('cp -p "$conf"') -and $sh.Contains('mv -f "$conf.ds3-new" "$conf"'))
    Assert ($sh.IndexOf('config-before.sha256') -lt $sh.IndexOf('mv -f "$conf.ds3-new"'))
    $ins=[IO.File]::ReadAllText((Join-Path $script:ReleaseRoot 'scripts/install.ps1'))
    Assert ($ins.IndexOf('Assert-Payload') -lt $ins.IndexOf('Write-Device $backupCmd'))
    Assert ([regex]::Matches($ins,"Invoke-Adb @\('reboot'\)").Count -eq 1)
}
Check 'production marker semantics: armed rejected; PID only where actually emitted' {
    Assert (Test-InstallMarker 0 'sched pid=123' '123')
    Assert (Test-InstallMarker 1 'entered pid=123' '123')
    Assert (-not (Test-InstallMarker 1 'entered pid=999' '123'))
    Assert (Test-InstallMarker 5 'sha256 matched pinned target' '123')
    Assert (Test-InstallMarker 8 'gap found veneer=0x12345000' '123')
    Assert (Test-InstallMarker 13 'transaction committed; hooks live' '123')
    Assert (-not (Test-InstallMarker 13 'armed pid=123' '123'))
}
Check 'forbidden artifacts: no vendor lib, diagnostics, dumps, logs or hidden scratch' {
    foreach($f in Get-ChildItem $script:ReleaseRoot -Force -Recurse -File) {
        $rel=$f.FullName.Substring($script:ReleaseRoot.Length+1).Replace('\','/')
        Assert ($rel -notmatch '(?i)(^|/)(\.git|node_modules|build|scratch|backups)/|libbluetooth[^/]*\.(so|stock|patched)|\.(dmp|core|log|bin|apk|exe|dll|tar|gz)$|tombstone|trace2|crash-diagnostic') $rel
        if($f.Extension -eq '.so') { Assert ($rel -ceq 'payload/ds3-uhid-hook/zygisk/armeabi-v7a.so') }
    }
}
Check 'privacy/secret/path scan across complete public tree' {
    foreach($f in Get-ChildItem $script:ReleaseRoot -Force -Recurse -File) {
        $text=[Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($f.FullName))
        foreach($pattern in @('(?i)(?:[0-9a-f]{2}:){5}[0-9a-f]{2}',
            '\b10\.\d+\.\d+\.\d+|\b192\.168\.\d+\.\d+|\b172\.(?:1[6-9]|2\d|3[01])\.\d+\.\d+',
            ('(?i)[a-z]:[\\/](?:Users|tmp)[\\/]|/ho'+'me/[^/\s]+/|/Use'+'rs/[^/\s]+/'),
            '(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)',
            '(?im)^\s*(?:LinkKey|password|token|secret)\s*=\s*[a-zA-Z0-9+/]{16,}\s*$')) {
            Assert (-not [regex]::IsMatch($text,$pattern)) ('PRIVACY_SCAN_FAILED: '+$f.Name)
        }
        # Hardware serial-like identifiers are never emitted by collection.
        Assert ($text -notmatch '(?i)\badb\s+-s\s+[a-z0-9]{8,}\b') ('SERIAL_SCAN_FAILED: '+$f.Name)
    }
}
Check 'checksums cover every shipped file and match' {
    $list=Join-Path $script:ReleaseRoot 'CHECKSUMS.txt'
    Assert (Test-Path $list) 'CHECKSUMS_MISSING'
    $seen=@{}
    foreach($line in [IO.File]::ReadAllLines($list)) {
        if(-not $line.Trim()) { continue }
        Assert ($line -cmatch '^([0-9a-f]{64})  (.+)$') 'CHECKSUM_FORMAT'
        $hash=$Matches[1];$rel=$Matches[2]
        Assert ($rel -notmatch '^/|^[a-zA-Z]:|(^|/)\.\.(/|$)' -and -not $seen.ContainsKey($rel))
        $file=Join-Path $script:ReleaseRoot $rel
        Assert ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $hash) ('CHECKSUM_FAILED: '+$rel)
        $seen[$rel]=$true
    }
    foreach($f in Get-ChildItem $script:ReleaseRoot -Recurse -File) {
        $rel=$f.FullName.Substring($script:ReleaseRoot.Length+1).Replace('\','/')
        if($rel -ne 'CHECKSUMS.txt') { Assert ($seen.ContainsKey($rel)) ('CHECKSUM_NOT_COVERED: '+$rel) }
    }
}
Check 'self-containment: relative references and required tree' {
    foreach($rel in @('README.md','README_RU.md','LICENSE','VERSION','CHANGELOG.md','docs/TECHNICAL.md','docs/PORTING.md','docs/TROUBLESHOOTING.md','docs/KNOWN_ISSUES.md','.github/workflows/release-check.yml','scripts/install.ps1','scripts/rollback.ps1','scripts/collect-diagnostics.ps1')) { Assert (Test-Path (Join-Path $script:ReleaseRoot $rel)) $rel }
    Assert ([IO.File]::ReadAllText((Join-Path $script:ReleaseRoot 'VERSION')).Trim() -ceq '1.0.0')
}
if($RequirePublishable) { Check 'publishable payload/provenance gate' { Assert-Payload } }
Check 'vendor signature data excluded' { & "$PSScriptRoot/vendor-cleanliness.ps1" }
Check 'license/provenance gate and approved production identity' {
    foreach($rel in @('THIRD_PARTY_NOTICES.md','LICENSES/Zygisk-0BSD.txt','LICENSES/Apache-2.0.txt','LICENSES/Bionic-BSD-2-Clause.txt','LICENSES/LLVM-Apache-2.0-with-LLVM-exception.txt')) { Assert (Test-Path (Join-Path $script:ReleaseRoot $rel)) $rel }
    $apache=[IO.File]::ReadAllText((Join-Path $script:ReleaseRoot 'LICENSES/Apache-2.0.txt'))
    Assert ($apache.Length -gt 9000 -and $apache.Contains('9. Accepting Warranty or Additional Liability.') -and $apache.Contains('END OF TERMS AND CONDITIONS'))
    $llvm=[IO.File]::ReadAllText((Join-Path $script:ReleaseRoot 'LICENSES/LLVM-Apache-2.0-with-LLVM-exception.txt'))
    Assert ($llvm.Contains('LLVM Exceptions') -and $llvm.Contains('Sections 4(a), 4(b) and 4(d)') -and $llvm.Contains('END OF TERMS AND CONDITIONS'))
    $bsd=[IO.File]::ReadAllText((Join-Path $script:ReleaseRoot 'LICENSES/Bionic-BSD-2-Clause.txt'))
    Assert ($bsd.Contains('2012 The Android Open Source Project') -and $bsd.Contains('2013 The Android Open Source Project') -and $bsd.Contains('SUCH DAMAGE.'))
    $zy=[IO.File]::ReadAllText((Join-Path $script:ReleaseRoot 'LICENSES/Zygisk-0BSD.txt'))
    Assert ($zy.Contains('John "topjohnwu" Wu') -and $zy.Contains('USE OR PERFORMANCE OF THIS SOFTWARE.'))
    $provenance=[IO.File]::ReadAllText((Join-Path $script:ReleaseRoot 'docs/PROVENANCE.md'))
    Assert ($provenance.Contains('sha256 provenance resolved: YES') -and $provenance.Contains('unresolved code-bearing provenance: NO'))
    Assert ($provenance.Contains('old unknown-provenance sha256 absent: YES') -and $provenance.Contains('raw vendor signature redistribution eliminated: YES'))
    Assert ($provenance.Contains($script:Profile.hook.sha256) -and $provenance.Contains('PRODUCTION_APPROVED_PUBLICATION_SAFE_REV7'))
    $payload=Join-Path $script:ReleaseRoot 'payload/ds3-uhid-hook/zygisk/armeabi-v7a.so'
    Assert-HookBytes ([IO.File]::ReadAllBytes($payload))
}
'OFFLINE_TESTS_PASS: '+$script:Pass+' checks; live installer acceptance not claimed'
