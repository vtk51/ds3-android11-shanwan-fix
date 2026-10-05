[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Transaction, [string]$Adb='adb', [string]$Serial='', [switch]$DryRun)
. "$PSScriptRoot/common.ps1"
$script:Adb=$Adb; $script:Serial=$Serial; $script:DryRun=[bool]$DryRun
if ($Transaction -notmatch '^\d{8}T\d{6}Z-[a-f0-9]{8}$') { throw 'BACKUP_MANIFEST_REJECTED' }
$remote="/data/adb/ds3-fix/transactions/$Transaction"
$manifest=[Text.Encoding]::UTF8.GetString((Read-DeviceBytes "$remote/manifest.json")) | ConvertFrom-Json
Get-RollbackPlan $manifest
if ((Read-Device "sha256sum '$remote/state.tar'").Split(' ')[0] -ne $manifest.archiveSha256) { throw 'BACKUP_VERIFICATION_FAILED' }
if ($DryRun) { return }
if ((Read-Device 'id -u') -ne '0') { throw 'UNSAFE_STATE' }
$expected=(Get-FileHash "$PSScriptRoot/transaction.sh" -Algorithm SHA256).Hash.ToLowerInvariant()
if ((Read-Device "sha256sum '$remote/transaction.sh'").Split(' ')[0] -ne $expected) { throw 'ROLLBACK_SCRIPT_REJECTED' }
$null=Write-Device "sh '$remote/transaction.sh' rollback '$Transaction'"
$null=Invoke-Adb @('reboot')
'ROLLBACK_RESTORED; one reboot requested; backup material retained unchanged'
