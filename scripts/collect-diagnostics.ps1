[CmdletBinding()]
param([string]$Adb='adb', [string]$Serial='', [string]$OutputDirectory='')
. "$PSScriptRoot/common.ps1"
$script:Adb=$Adb; $script:Serial=$Serial
if(-not $OutputDirectory) { $OutputDirectory=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) ('DS3Fix/diagnostics/'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')) }
# Deliberately no full getprop, bt_config, dumpsys, logcat, serial or crash dumps.
$result=[ordered]@{schemaVersion=1; api=Invoke-Adb @('shell','getprop','ro.build.version.sdk');
    fingerprint=Invoke-Adb @('shell','getprop','ro.build.fingerprint');
    abi=Invoke-Adb @('shell','getprop','ro.product.cpu.abi');
    root=$false;magiskVersion='';zygisk='';selinux='';bluetoothArchitecture='';maps=@();libraries=@();ds3=@();magiskFailureSignature=$false}
try {
    $result.root=(Read-Device 'id -u') -eq '0'
    if ($result.root) {
        $result.magiskVersion=Read-Device 'magisk -V'
        $result.zygisk=Read-Device 'magisk --sqlite ''SELECT value FROM settings WHERE key="zygisk";'''
        $result.selinux=Read-Device 'getenforce'
        $result.magiskFailureSignature=(Read-Device 'if test -f /cache/magisk.log; then grep -F "Magisk environment incomplete, abort" /cache/magisk.log; fi') -match 'Magisk environment incomplete, abort'
        $pidBt=Read-Device 'pidof com.android.bluetooth'
        if($pidBt -match '^\d+$') {
            $exe=Read-Device "readlink /proc/$pidBt/exe"
            $result.bluetoothArchitecture=Get-Hex (Read-DeviceBytes $exe) 0 20
            $result.maps=@((Read-Device "cat /proc/$pidBt/maps") -split "`n" | Where-Object { $_ -match '/system/lib(?:64)?/libbluetooth\.so$' })
        }
        foreach($path in @('/system/lib/libbluetooth.so','/system/lib64/libbluetooth.so')) {
            if((Read-Device "if test -f '$path'; then echo YES; fi") -eq 'YES') {
                $b=Read-DeviceBytes $path
                # ELF PT_NOTE GNU BuildID, independent of the existing profile.
                $buildId=''
                if((Get-Hex $b 0 6) -eq '7f454c460101') {
                    $phoff=[BitConverter]::ToUInt32($b,28); $entsize=[BitConverter]::ToUInt16($b,42); $num=[BitConverter]::ToUInt16($b,44)
                    for($i=0;$i -lt $num;$i++) {
                        $at=$phoff+$i*$entsize
                        if([BitConverter]::ToUInt32($b,$at) -ne 4) { continue }
                        $start=[BitConverter]::ToUInt32($b,$at+4); $end=$start+[BitConverter]::ToUInt32($b,$at+16)
                        for($n=$start;$n+12 -le $end;) {
                            $ns=[BitConverter]::ToUInt32($b,$n);$ds=[BitConverter]::ToUInt32($b,$n+4);$type=[BitConverter]::ToUInt32($b,$n+8)
                            $desc=$n+12+4*[Math]::Ceiling($ns/4)
                            if($type -eq 3 -and $ns -eq 4 -and (Get-Hex $b ($n+12) 4) -eq '474e5500') { $buildId=Get-Hex $b $desc $ds }
                            $n=$desc+4*[Math]::Ceiling($ds/4)
                        }
                    }
                }
                $signatures=@()
                foreach($s in $script:Profile.library.signatures) { if($s.offset+$s.length -le $b.Length) { $signatures+=@{role=$s.role;offset=$s.offset;length=$s.length;sha256=Get-WindowSha $b $s.offset $s.length} } }
                $result.libraries+=@{path=$path;sha256=Get-Sha $b;size=$b.Length;buildId=$buildId;signatures=$signatures}
            }
        }
        $inputs=Read-Device 'cat /proc/bus/input/devices'
        $result.ds3=@($inputs -split "`n" | Where-Object { $_ -match '^I:.*Vendor=054c Product=0268|^N: Name="SHANWAN' })
    }
} catch { $result['error']='DIAGNOSTICS_INCOMPLETE' }
$json=$result | ConvertTo-Json -Depth 12
# Redact unexpected identifiers from unfamiliar firmware before writing or sharing.
$json=[regex]::Replace($json,'(?i)(?:[0-9a-f]{2}:){5}[0-9a-f]{2}','<BDADDR_REDACTED>')
$json=[regex]::Replace($json,'\b(?:10|127)\.\d+\.\d+\.\d+|\b192\.168\.\d+\.\d+|\b172\.(?:1[6-9]|2\d|3[01])\.\d+\.\d+','<IP_REDACTED>')
$null=New-Item -ItemType Directory -Path $OutputDirectory -Force
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'firmware-profile-evidence.json'),$json,(New-Object Text.UTF8Encoding($false)))
'DIAGNOSTICS_COLLECTED: review firmware-profile-evidence.json before sharing'
