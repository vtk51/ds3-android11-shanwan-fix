[CmdletBinding()]
param([string]$Adb='adb', [string]$Serial='')
. "$PSScriptRoot/common.ps1"
$script:Adb=$Adb; $script:Serial=$Serial
try { Get-Classification (Get-State) } catch { 'UNSAFE_STATE' }
