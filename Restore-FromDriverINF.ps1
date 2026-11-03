# Restore GPU driver identity by re-enumerating hardware and reinstalling its
# currently bound Windows INF. Does not read a saved GPU Registry backup.
# Windows PowerShell 5.1, Windows 10 version 2004 or Windows 11.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host 'Dang yeu cau Administrator qua UAC...' -ForegroundColor Yellow
    try {
        $arguments = @(
            '-NoProfile', '-NoExit', '-ExecutionPolicy', 'Bypass',
            '-File', ('"' + $PSCommandPath + '"')
        )
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments -ErrorAction Stop
    } catch {
        Write-Host ('Khong mo duoc cua so Administrator: ' + $_.Exception.Message) -ForegroundColor Red
    }
    return
}

Write-Host ''
Write-Host '===== ONE CLICK RESTORE - DRIVER INF =====' -ForegroundColor Cyan
Write-Host 'Khong can backup, khong tu ghi ten GPU vao Registry.' -ForegroundColor Gray

# Use PnP device enumeration, not display descriptions that may have been changed.
$devices = @()
try {
    $devices = @(Get-PnpDevice -Class Display -PresentOnly -ErrorAction Stop |
        Where-Object { $_.InstanceId -match '(?i)^PCI\\' })
} catch {
    Write-Host ('Khong doc duoc Get-PnpDevice: ' + $_.Exception.Message) -ForegroundColor Yellow
}
if ($devices.Count -eq 0) {
    try {
        $devices = @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop |
            Where-Object { $_.PNPClass -eq 'Display' -and $_.PNPDeviceID -match '(?i)^PCI\\' -and $_.ConfigManagerErrorCode -eq 0 } |
            ForEach-Object { [pscustomobject]@{ InstanceId = [string]$_.PNPDeviceID; FriendlyName = [string]$_.Name } })
    } catch {
        Write-Host ('Khong doc duoc GPU tu CIM: ' + $_.Exception.Message) -ForegroundColor Yellow
    }
}
$devices = @($devices | Group-Object -Property InstanceId | ForEach-Object { $_.Group[0] } | Sort-Object -Property InstanceId)
if ($devices.Count -eq 0) {
    Write-Host 'Khong tim thay GPU PCI dang hoat dong. Khong thay doi he thong.' -ForegroundColor Red
    return
}

# Device INF comes from the currently installed, signed-driver metadata.
$signed = @()
try { $signed = @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop) }
catch { Write-Host ('Khong doc duoc driver CIM: ' + $_.Exception.Message) -ForegroundColor Yellow }
$items = @()
foreach ($dev in $devices) {
    $id = [string]$dev.InstanceId
    $matched = @($signed | Where-Object { $_.DeviceID -ieq $id } | Select-Object -First 1)
    $inf = ''
    try {
        $inf = ([string](Get-PnpDeviceProperty -InstanceId $id -KeyName 'DEVPKEY_Device_DriverInfPath' -ErrorAction Stop).Data).Trim()
    } catch { }
    if (-not $inf -and $matched.Count -eq 1) {
        $inf = ([string]$matched[0].InfName).Trim()
    }
    $infOK = [bool]($inf -match '(?i)^[a-z0-9][a-z0-9_-]*\.inf$')
    $path = if ($infOK) { Join-Path (Join-Path $env:windir 'INF') $inf } else { '' }
    $infOK = $infOK -and (Test-Path -LiteralPath $path)
    $label = if ($matched.Count -eq 1 -and $matched[0].DeviceName) {
        [string]$matched[0].DeviceName
    } elseif ($dev.FriendlyName) { [string]$dev.FriendlyName } else { $id }
    $items += [pscustomobject]@{
        InstanceId=$id; DisplayName=$label; InfName=$inf; InfPath=$path; Ready=$infOK
    }
}

Write-Host ''
for ($i = 0; $i -lt $items.Count; $i++) {
    $item = $items[$i]
    $status = if ($item.Ready) { $item.InfName } else { 'INF khong tim thay' }
    Write-Host ('  [{0}] {1} | {2}' -f ($i + 1), $item.DisplayName, $status)
}
$target = $null
if ($items.Count -eq 1) {
    $target = $items[0]
} else {
    Write-Host '  [0] Huy' -ForegroundColor DarkGray
    $choice = ([string](Read-Host 'Chon so GPU can Restore')).Trim()
    $number = 0
    if (-not [int]::TryParse($choice, [ref]$number) -or $number -lt 1 -or $number -gt $items.Count) {
        Write-Host 'Da huy hoac lua chon khong hop le. Khong thay doi gi.' -ForegroundColor Yellow
        return
    }
    $target = $items[$number - 1]
}

if (-not $target.Ready) {
    Write-Host 'Khong xac dinh duoc INF dang cai cho GPU nay. Khong go thiet bi.' -ForegroundColor Red
    return
}
$version = [Environment]::OSVersion.Version
if ($version.Major -lt 10 -or ($version.Build -lt 19041)) {
    Write-Host 'Can Windows 10 version 2004 tro len de dung PnPUtil /remove-device.' -ForegroundColor Red
    return
}

Write-Host ''
Write-Host ('GPU: ' + $target.DisplayName) -ForegroundColor Cyan
Write-Host ('Driver INF: ' + $target.InfName) -ForegroundColor Cyan
Write-Host ('Instance ID: ' + $target.InstanceId) -ForegroundColor DarkGray
Write-Host 'Windows se go nhan dien thiet bi, quet lai va cai lai driver.' -ForegroundColor Yellow
Write-Host 'Man hinh co the tam thoi den. Luu cong viec truoc khi su dung lenh nay.' -ForegroundColor Yellow

$removed = $false
try {
    Write-Host ''
    Write-Host '[1/3] Re-enumerate GPU...' -ForegroundColor Cyan
    & pnputil.exe /remove-device "$($target.InstanceId)" 2>&1 | Out-Host
    $removeExit = $LASTEXITCODE
    if ($removeExit -ne 0) {
        Write-Host ('Khong the go device instance (exit ' + $removeExit + ').') -ForegroundColor Red
        return
    }
    $removed = $true
} catch {
    Write-Host ('Loi khi go device instance: ' + $_.Exception.Message) -ForegroundColor Red
    return
} finally {
    # Always trigger a fresh scan, even if the remove command failed midway.
    Write-Host '[2/3] Quet lai phan cung...' -ForegroundColor Cyan
    try { & pnputil.exe /scan-devices 2>&1 | Out-Host }
    catch { Write-Host ('Loi khi quet phan cung: ' + $_.Exception.Message) -ForegroundColor Red }
}
if (-not $removed) { return }

Write-Host '[3/3] Windows gan lai driver tu Driver Store...' -ForegroundColor Cyan
# No /add-driver /install here: that flag can affect all matching GPUs.
# The package was verified in Windows\INF before removal; re-enumeration
# allows Windows PnP to use its installed ranked driver normally.
try {
    & pnputil.exe /scan-devices 2>&1 | Out-Host
} catch {
    Write-Host ('Quet lai thiet bi that bai: ' + $_.Exception.Message) -ForegroundColor Red
    return
}

Start-Sleep -Seconds 2
try {
    $current = @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop |
        Where-Object { $_.DeviceID -ieq $target.InstanceId } | Select-Object -First 1)
    if ($current.Count -eq 1) {
        Write-Host ('Driver hien tai: ' + [string]$current[0].DeviceName) -ForegroundColor Green
        Write-Host ('INF: ' + [string]$current[0].InfName)
        if ([string]$current[0].InfName -ine $target.InfName) {
            Write-Host ('CANH BAO: Windows da chon INF khac (' + [string]$current[0].InfName + ') thay vi ' + $target.InfName) -ForegroundColor Yellow
        }
    } else {
        Write-Host 'Windows chua hoan tat nhan dien GPU. Kiem tra Device Manager hoac khoi dong lai.' -ForegroundColor Yellow
    }
} catch {
    Write-Host ('Khong doc lai duoc driver: ' + $_.Exception.Message) -ForegroundColor Yellow
}
Write-Host 'Da thuc hien Restore theo driver INF. Khong dung gpu_backup.json.' -ForegroundColor Cyan
