[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$remoteNames = @('MI RC', '小米蓝牙语音遥控器')
$remote = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
    Where-Object { $_.FriendlyName -in $remoteNames } |
    Select-Object -First 1

$gatt = @(
    Get-PnpDevice -ErrorAction SilentlyContinue |
        Where-Object { $_.InstanceId -like '*VID&012717_PID&32B8*' }
)

$atvv = Get-PnpDevice -ErrorAction SilentlyContinue |
    Where-Object { $_.InstanceId -like '*AB5E0001*' } |
    Select-Object -First 1

$audioEndpoints = @(
    Get-PnpDevice -Class AudioEndpoint -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -like '*VB-Audio Virtual Cable*' }
)

$sayAllCandidates = @(
    (Join-Path $env:LOCALAPPDATA '无线麦 SayAll\sayall-windows-app.exe'),
    'D:\Users\admin\AppData\Local\无线麦 SayAll\sayall-windows-app.exe'
)
$sayAllExe = $sayAllCandidates |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1

$sayAllProcess = Get-Process -Name 'sayall-windows-app' -ErrorAction SilentlyContinue |
    Select-Object -First 1

$result = [ordered]@{
    SayAllInstalled = [bool]$sayAllExe
    SayAllVersion = if ($sayAllExe) {
        (Get-Item -LiteralPath $sayAllExe).VersionInfo.FileVersion
    } else {
        'N/A'
    }
    SayAllRunning = [bool]$sayAllProcess
    RemoteName = if ($remote) { $remote.FriendlyName } else { 'NOT_FOUND' }
    RemoteStatus = if ($remote) { $remote.Status } else { 'N/A' }
    GattNodes = $gatt.Count
    AtvvOk = [bool]$atvv
    CableInput = [bool]($audioEndpoints | Where-Object FriendlyName -like 'CABLE Input*')
    CableOutput = [bool]($audioEndpoints | Where-Object FriendlyName -like 'CABLE Output*')
    Cable16ch = [bool]($audioEndpoints | Where-Object FriendlyName -like 'CABLE In 16ch*')
}

$criticalPass = (
    $result.SayAllInstalled -and
    $result.SayAllVersion -eq '1.0.0' -and
    $result.RemoteStatus -eq 'OK' -and
    $result.GattNodes -gt 0 -and
    $result.AtvvOk -and
    $result.CableInput -and
    $result.CableOutput -and
    $result.Cable16ch
)

$result['Overall'] = if ($criticalPass) { 'PASS' } else { 'FAIL' }
[pscustomobject]$result | Format-List

if (-not $criticalPass) {
    exit 1
}

exit 0
