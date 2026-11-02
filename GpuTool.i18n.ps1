# Windows GPU utility: English / Vietnamese (ASCII).
# Read SAFETY.md before using system-changing functions.
[CmdletBinding()]
param(
    [ValidateSet('en', 'vi')]
    [string]$Language = 'vi'
)

$ErrorActionPreference = 'Stop'
$localePath = Join-Path (Join-Path $PSScriptRoot 'locales') ($Language.ToLowerInvariant() + '.json')
if (-not (Test-Path -LiteralPath $localePath)) { throw ('Missing language file: ' + $localePath) }
$Script:UiStrings = Get-Content -LiteralPath $localePath -Raw -Encoding UTF8 | ConvertFrom-Json

function Get-UiText([string]$Key) {
    $entry = $Script:UiStrings.PSObject.Properties[$Key]
    if ($null -eq $entry -or $entry.Value -isnot [string]) { throw ('Missing UI string: ' + $Key) }
    return [string]$entry.Value
}

$ErrorActionPreference = 'Stop'

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$admin = (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Host (Get-UiText 'K0001') -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoExit','-ExecutionPolicy','Bypass','-File',("`"" + $PSCommandPath + "`""),'-Language',$Language)
    exit
}

$ClassKey    = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
$EnumRoot    = 'HKLM:\SYSTEM\CurrentControlSet\Enum'
$SpoofName   = 'NVIDIA GeForce GTX 1050 Ti'
$SpoofVendor = 'NVIDIA'
$AppName     = (Get-UiText 'K0190')
$BackupFile  = Join-Path $PSScriptRoot 'gpu_backup.json'

$LogSensitive = $false
$LogEnabled   = $false
$LogDir   = Join-Path $env:LOCALAPPDATA $AppName
$LogFile  = Join-Path $LogDir 'gputool.log'
$LogMaxKB = 256

function Get-ShortHash([string]$s, [int]$n = 8) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $h = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($s)) } finally { $sha.Dispose() }
    $sb = ''
    foreach ($b in $h) { $sb += $b.ToString('x2') }
    return $sb.Substring(0, $n)
}

function Hide-Sensitive([string]$msg) {
    if ($LogSensitive) { return $msg }
    $s = [string]$msg
    $s = [regex]::Replace($s, 'PCI\\VEN_[0-9A-Fa-f]{4}&DEV_[0-9A-Fa-f]{4}[^\s,''")\]]*',
        [System.Text.RegularExpressions.MatchEvaluator]{ param($m) 'PCI[DEV:' + (Get-ShortHash $m.Value 8) + ']' })
    $s = [regex]::Replace($s, 'DELTA-[0-9A-Za-z-]+',
        [System.Text.RegularExpressions.MatchEvaluator]{ param($m) 'DELTA-***(len=' + $m.Value.Length + ')' })
    $s = [regex]::Replace($s, '(NVIDIA|AMD)\s+[A-Za-z0-9][A-Za-z0-9 ._-]{2,40}',
        [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Groups[1].Value + '[GPU:' + (Get-ShortHash $m.Value 6) + ']' })
    $s = [regex]::Replace($s, 'Intel\(R\)\s+[A-Za-z0-9][A-Za-z0-9() ._-]{2,40}',
        [System.Text.RegularExpressions.MatchEvaluator]{ param($m) 'Intel[GPU:' + (Get-ShortHash $m.Value 6) + ']' })
    $s = [regex]::Replace($s, '\b[0-9A-F]{32}\b',
        [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Value.Substring(0, 8) + '...' })
    $s = [regex]::Replace($s, '(C:\\Users\\)[^\\\s,''"]+', '$1<user>')
    return $s
}

function Log($msg) {
    if (-not $LogEnabled) { return }
    try {
        if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
        if ((Test-Path $LogFile) -and ((Get-Item $LogFile).Length -gt ($LogMaxKB * 1024))) {
            $tail = @(Get-Content $LogFile -Tail 200 -Encoding UTF8)
            [System.IO.File]::WriteAllLines($LogFile, $tail, (New-Object System.Text.UTF8Encoding $false))
        }
        $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), (Hide-Sensitive $msg)
        Add-Content -Path $LogFile -Value $line -Encoding UTF8
    } catch { }
}

foreach ($legacy in @('gputool.log', 'icc_original.txt')) {
    $lp = Join-Path $PSScriptRoot $legacy
    if (Test-Path $lp) { try { Remove-Item $lp -Force } catch { } }
}

# ============================================================
# ============================================================
$SettingsRegKey = "HKCU:\Software\$AppName"

function Get-HwId([string]$instId) {
    if ([string]::IsNullOrWhiteSpace($instId)) { return '' }
    $s = $instId.ToLowerInvariant()
    $i = $s.IndexOf('\')
    if ($i -ge 0) { $s = $s.Substring($i + 1) }
    return $s
}

function Read-InfLines([string]$infName) {
    if ([string]::IsNullOrWhiteSpace($infName)) { return $null }
    $p = Join-Path 'C:\Windows\INF' $infName
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    foreach ($e in @('Unicode', 'UTF8', 'Default')) {
        try {
            $t = Get-Content -LiteralPath $p -Encoding $e -ErrorAction Stop
            if ($t -and (($t -join "`n") -match 'VEN_')) { return $t }
        } catch { }
    }
    return $null
}

function Resolve-RealDeviceFromInf([string]$infName, [string]$matchingDeviceId) {
    $lines = Read-InfLines $infName
    if (-not $lines) { return $null }
    $mid = [string]$matchingDeviceId
    if ([string]::IsNullOrWhiteSpace($mid)) { return $null }
    $mid = $mid.Trim()

    $levels = New-Object System.Collections.ArrayList
    [void]$levels.Add($mid)
    $noSub = ($mid -split '&SUBSYS')[0]
    if ($noSub -ne $mid) { [void]$levels.Add($noSub) }
    $devPart = @($mid -split '&' | Where-Object { $_ -match '^DEV_[0-9A-Fa-f]{4}' } | Select-Object -First 1)
    if ($devPart.Count -gt 0 -and $devPart[0]) { [void]$levels.Add([string]$devPart[0]) }

    $token = $null
    foreach ($lv in $levels) {
        $needle = ([string]$lv).ToLowerInvariant()
        foreach ($ln in $lines) {
            $t = ([string]$ln).Trim()
            if ($t -eq '' -or $t.StartsWith(';')) { continue }
            if (-not $t.ToLowerInvariant().Contains($needle)) { continue }
            if ($t -match '^\s*%?(?<tok>[^%=,\s]+?)%?\s*=\s*(?<sec>[^,]+)\s*,\s*(?<hw>.+)$') {
                $token = $matches['tok']; break
            }
        }
        if ($token) { break }
    }
    if (-not $token) { return $null }

    $rx = '^\s*' + [regex]::Escape($token) + '\s*=\s*"([^"]*)"'
    $name = $null
    foreach ($ln in $lines) {
        if ($ln -match $rx) { $name = $matches[1]; break }
    }
    if (-not $name) { return $null }
    return @{ Name = $name; Token = $token }
}

function Get-ProviderFromMfg([string]$mfg) {
    if ([string]::IsNullOrWhiteSpace($mfg)) { return $null }
    if ($mfg.Contains(';')) {
        $tail = $mfg.Substring($mfg.LastIndexOf(';') + 1).Trim()
        if ($tail) { return $tail }
    }
    return $mfg.Trim()
}

function Classify-GpuKind([string]$hwid, [string]$service, [string]$location) {
    $ven = ''
    if ($hwid -match 'ven_([0-9a-fA-F]{4})') { $ven = $matches[1].ToLowerInvariant() }

    if ($service -match '^(igfx|iigd|igdkmd|igd|ialm)') { return 'Integrated' }
    if ($ven -eq '10de') { return 'Discrete' }

    $bus = $null; $dev = $null
    if ($location -match '\((-?\d+),(-?\d+),(-?\d+)\)') {
        $bus = [int]$matches[1]; $dev = [int]$matches[2]
    }
    $onRootBus = ($null -ne $bus -and $bus -le 0 -and $dev -le 2)

    if ($ven -eq '8086') { return $(if ($onRootBus) { 'Integrated' } else { 'Discrete' }) }
    if ($ven -eq '1002') { return $(if ($onRootBus) { 'Integrated' } else { 'Discrete' }) }
    return $(if ($onRootBus) { 'Integrated' } else { 'Discrete' })
}

function Get-RealNameFor($a) {
    $r = Resolve-RealDeviceFromInf $a.InfPath $a.InstId
    if ($r -and $r.Name) { return @{ Name = $r.Name; Token = $r.Token } }
    $hi = (Get-ItemProperty $a.Path -ErrorAction SilentlyContinue).'HardwareInformation.AdapterString'
    if ($hi -is [byte[]]) { $n = ([System.Text.Encoding]::Unicode.GetString($hi) -replace "`0+$", '') }
    elseif ($hi) { $n = [string]$hi } else { $n = $null }
    if ($n) { return @{ Name = $n; Token = $null } }
    return $null
}

function Restore-Adapters($ads) {
    $allOk   = $true
    $changed = @()
    foreach ($a in @($ads | Where-Object { $_ -and $_.IsReal })) {
        $rn = Get-RealNameFor $a
        if (-not $rn) {
            Write-Host ((Get-UiText 'K0417') -f $a.Key, $a.InfPath) -ForegroundColor Red
            $allOk = $false; continue
        }
        $real = $rn.Name; $tok = $rn.Token
        $hasEnum = -not [string]::IsNullOrEmpty([string]$a.EnumPath)
        $prov = $null
        if ($hasEnum) { $prov = Get-ProviderFromMfg ([string](Get-ItemProperty -LiteralPath $a.EnumPath -ErrorAction SilentlyContinue).Mfg) }
        if (-not $prov) { $prov = $a.Provider }
        try {
            Set-ItemProperty -LiteralPath $a.Path -Name 'DriverDesc'   -Value $real -ErrorAction Stop
            Set-ItemProperty -LiteralPath $a.Path -Name 'ProviderName' -Value $prov -ErrorAction Stop
            $okv = $real
            if ($hasEnum) {
                $okv = if ($tok) { '@{0},%{1}%;{2}' -f $a.InfPath, $tok, $real } else { $real }
                Set-ItemProperty -LiteralPath $a.EnumPath -Name 'DeviceDesc' -Value $okv -ErrorAction Stop
            }
            $c1 = [string](Get-ItemProperty -LiteralPath $a.Path).DriverDesc
            $c2 = if ($hasEnum) { [string](Get-ItemProperty -LiteralPath $a.EnumPath -ErrorAction SilentlyContinue).DeviceDesc } else { $real }
            if ($c1 -eq $real -and $c2 -eq $okv) {
                Write-Host ((Get-UiText 'K0418') -f $a.Key, $real) -ForegroundColor Green
                Log ((Get-UiText 'K0419') -f $a.Key, $real)
                if ($a.FullInst) { $changed += $a.FullInst }
            } else {
                $allOk = $false
                Write-Host ((Get-UiText 'K0420') -f $a.Key, $c1, $c2) -ForegroundColor Red
            }
        } catch {
            $allOk = $false
            Write-Host ((Get-UiText 'K0421') -f $a.Key, $_.Exception.Message) -ForegroundColor Red
        }
    }
    Restart-Adapters $changed
    return $allOk
}

function Invoke-RestoreFromInf {
    Write-Host (Get-UiText 'K0059') -ForegroundColor Cyan
    Write-Host (Get-UiText 'K0422') -ForegroundColor DarkGray
    $ads = @(Get-DisplayAdapters | Where-Object { $_.IsReal })
    if ($ads.Count -eq 0) { Write-Host (Get-UiText 'K0040') -ForegroundColor Red; return $false }
    return (Restore-Adapters $ads)
}

function Get-DisplayAdapters {
    $list = @()
    $list = @()
    $pnpDevs = @(Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like 'PCI\*' })
    Log ((Get-UiText 'K0023') + $pnpDevs.Count)

    Get-ChildItem $ClassKey -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match '^\d{4}$' } |
        ForEach-Object {
            try {
                $p = Get-ItemProperty $_.PSPath
                if (-not $p.DriverDesc) { return }
                $instId = [string]$p.MatchingDeviceId
                $isReal = ($instId -like 'pci\*')
                $enumPath = $null; $enumDesc = $null; $fullInst = $null
                $svc = ''; $locInfo = ''
                if ($isReal) {
                    $dev = $pnpDevs | Where-Object { $_.InstanceId -like "$instId*" } | Select-Object -First 1
                    if ($dev) {
                        $fullInst = $dev.InstanceId
                        $enumKeyPath = "$EnumRoot\$fullInst"
                        if (Test-Path $enumKeyPath) {
                            $enumPath = $enumKeyPath
                            $e = Get-ItemProperty $enumKeyPath -ErrorAction SilentlyContinue
                            $enumDesc = [string]$e.DeviceDesc
                            $svc      = [string]$e.Service
                            $locInfo  = [string]$e.LocationInformation
                            Log ((Get-UiText 'K0024') -f $_.PSChildName, $enumKeyPath)
                        } else {
                            Log ((Get-UiText 'K0025') -f $_.PSChildName, $enumKeyPath)
                        }
                    } else {
                        Log ((Get-UiText 'K0026') -f $_.PSChildName, $instId)
                    }
                }
                $list += [pscustomobject]@{
                    Key      = $_.PSChildName
                    Desc     = [string]$p.DriverDesc
                    Provider = [string]$p.ProviderName
                    InstId   = $instId
                    FullInst = $fullInst
                    IsReal   = $isReal
                    EnumPath = $enumPath
                    EnumDesc = $enumDesc
                    Path     = $_.PSPath
                    HWID     = (Get-HwId $instId)
                    InfPath  = [string]$p.InfPath
                    Service  = $svc
                    Location = $locInfo
                    GpuKind  = $(if ($isReal) { Classify-GpuKind (Get-HwId $instId) $svc $locInfo } else { 'Other' })
                }
            } catch {
                Log ((Get-UiText 'K0027') + $_.Exception.Message)
            }
        }
    return $list
}

function Restart-Adapters($fullInstIds) {
    $anyTried = $false
    foreach ($i in $fullInstIds) {
        if (-not $i) { continue }
        $anyTried = $true
        Write-Host (Get-UiText 'K0028') -ForegroundColor Cyan
        Log "pnputil /restart-device $i"
        $null = & pnputil.exe /restart-device "$i" 2>&1
        Log ((Get-UiText 'K0029') + $LASTEXITCODE)
        if ($LASTEXITCODE -ne 0) {
            Write-Host (Get-UiText 'K0030') -ForegroundColor Yellow
        }
    }
    if (-not $anyTried) {
        Write-Host (Get-UiText 'K0031') -ForegroundColor Yellow
        Log (Get-UiText 'K0032')
    }
}

function Show-Current {
    Write-Host ""
    Write-Host (Get-UiText 'K0033') -ForegroundColor Cyan
    $ads = Get-DisplayAdapters
    if (-not $ads) { Write-Host (Get-UiText 'K0034') }
    foreach ($a in $ads) {
        if (-not $a.IsReal) { $tag = (Get-UiText 'K0036') }
        elseif ($a.GpuKind -eq 'Discrete')   { $tag = (Get-UiText 'K0423') }
        elseif ($a.GpuKind -eq 'Integrated') { $tag = (Get-UiText 'K0424') }
        else { $tag = (Get-UiText 'K0035') }
        $name = if ($a.EnumDesc) { $a.EnumDesc } else { $a.Desc }
        Write-Host ((Get-UiText 'K0037') -f $a.Key, $name, $a.Provider, $tag)
    }
    Write-Host ""
    Write-Host (Get-UiText 'K0038') -ForegroundColor Cyan
    Get-CimInstance Win32_VideoController | ForEach-Object {
        Write-Host ("  {0}   [{1}]" -f $_.Name, $_.PNPDeviceID)
    }
}

function Invoke-Spoof {
    Log (Get-UiText 'K0039')
    $ads = Get-DisplayAdapters
    if (-not $ads) { Write-Host (Get-UiText 'K0040') -ForegroundColor Red; return }

    $realAds = @($ads | Where-Object { $_.IsReal })
    if (-not $realAds) { Write-Host (Get-UiText 'K0041') -ForegroundColor Red; return }
    $dgpus = @($realAds | Where-Object { $_.GpuKind -eq 'Discrete' })
    $igpus = @($realAds | Where-Object { $_.GpuKind -eq 'Integrated' })

    if ($dgpus.Count -gt 0) {
        $targets = $dgpus
        $skipped = $igpus
        Write-Host ((Get-UiText 'K0425') -f $dgpus.Count, $igpus.Count) -ForegroundColor Cyan
        foreach ($a in $dgpus) { Write-Host ((Get-UiText 'K0426') -f $a.Key, $(if ($a.EnumDesc) { $a.EnumDesc } else { $a.Desc })) -ForegroundColor Green }
        foreach ($a in $igpus) { Write-Host ((Get-UiText 'K0427') -f $a.Key, $(if ($a.EnumDesc) { $a.EnumDesc } else { $a.Desc })) -ForegroundColor DarkGray }
    } else {
        $targets = $realAds
        $skipped = @()
        Write-Host (Get-UiText 'K0428') -ForegroundColor Yellow
    }

    $badEnum = @($targets | Where-Object { -not $_.EnumPath })
    if ($badEnum.Count -gt 0) {
        Write-Host (Get-UiText 'K0429') -ForegroundColor Red
        Log ((Get-UiText 'K0430') + (@($badEnum | ForEach-Object { $_.Key }) -join ','))
        return
    }

    $fixIgpu = @($skipped | Where-Object { $_.Desc -eq $SpoofName -or $_.EnumDesc -eq $SpoofName })
    if ($fixIgpu.Count -gt 0) {
        Write-Host ((Get-UiText 'K0431') -f $fixIgpu.Count) -ForegroundColor Yellow
        $null = Restore-Adapters $fixIgpu
    }

    $changed = @()
    $failed = @()
    foreach ($a in $targets) {
        if ($a.Desc -ne $SpoofName -or $a.EnumDesc -ne $SpoofName) {
            Set-ItemProperty -Path $a.Path -Name DriverDesc -Value $SpoofName
            Set-ItemProperty -Path $a.Path -Name ProviderName -Value $SpoofVendor
            if ($a.EnumPath) {
                try {
                    Set-ItemProperty -Path $a.EnumPath -Name DeviceDesc -Value $SpoofName -ErrorAction Stop
                } catch {
                    $failed += $a.Key
                    Log ((Get-UiText 'K0048') + $_.Exception.Message)
                    Write-Host ((Get-UiText 'K0049') -f $_.Exception.Message) -ForegroundColor Yellow
                }
            } else {
                $failed += $a.Key
                Log (Get-UiText 'K0050')
            }
            $chk1 = [string](Get-ItemProperty $a.Path).DriverDesc
            $chk2 = if ($a.EnumPath) { [string](Get-ItemProperty $a.EnumPath -ErrorAction SilentlyContinue).DeviceDesc } else { '' }
            if ($chk1 -eq $SpoofName -and $chk2 -eq $SpoofName) {
                $changed += $a.FullInst
                Write-Host ((Get-UiText 'K0051') -f $a.Key, $a.Desc, $SpoofName) -ForegroundColor Green
                Log ((Get-UiText 'K0052') -f $a.Key)
            } else {
                $failed += $a.Key
                Log ((Get-UiText 'K0053') -f $a.Key, $chk1, $chk2)
                Write-Host ((Get-UiText 'K0054') -f $a.Key) -ForegroundColor Red
            }
        }
    }
    if ($changed.Count -eq 0) {
        if ($failed.Count -eq 0) { Write-Host (Get-UiText 'K0055') -ForegroundColor Yellow }
        return
    }
    Restart-Adapters $changed
    Write-Host ""
    if ($failed.Count -gt 0) {
        Write-Host (Get-UiText 'K0056') -ForegroundColor Yellow
    } else {
        Write-Host ((Get-UiText 'K0057') -f $SpoofName) -ForegroundColor Green
        Write-Host (Get-UiText 'K0058') -ForegroundColor DarkGray
    }
}

function Invoke-Restore {
    Log (Get-UiText 'K0059')
    return (Invoke-RestoreFromInf)
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class ProcThrottle {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool SetProcessInformation(IntPtr h, int cls, ref PROCESS_POWER_THROTTLING_STATE info, uint size);
    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_POWER_THROTTLING_STATE {
        public uint Version;
        public uint ControlMask;
        public uint StateMask;
    }
    public const uint PROCESS_SET_INFORMATION = 0x0200;
    public const int ProcessPowerThrottling = 4;
    public static bool SetEco(int pid, bool enable) {
        IntPtr h = OpenProcess(PROCESS_SET_INFORMATION, false, pid);
        if (h == IntPtr.Zero) return false;
        try {
            PROCESS_POWER_THROTTLING_STATE s = new PROCESS_POWER_THROTTLING_STATE();
            s.Version = 1;
            if (enable) {
                s.ControlMask = 1; // PROCESS_POWER_THROTTLING_EXECUTION_SPEED
                s.StateMask   = 1;
            } else {
                s.ControlMask = 0;
                s.StateMask   = 0;
            }
            return SetProcessInformation(h, ProcessPowerThrottling, ref s, (uint)Marshal.SizeOf(typeof(PROCESS_POWER_THROTTLING_STATE)));
        } finally { CloseHandle(h); }
    }
}
"@

$AceProcNames = @('SGuard*')

function Get-AceProcesses {
    return @(Get-Process -Name $AceProcNames -ErrorAction SilentlyContinue)
}

function Test-IsAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Write-AdminHint {
    if (-not (Test-IsAdmin)) {
        Write-Host (Get-UiText 'K0432') -ForegroundColor Yellow
    }
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class ProcThrottleProbe {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool GetProcessInformation(IntPtr h, int cls, out PROCESS_POWER_THROTTLING_STATE info, uint size);
    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_POWER_THROTTLING_STATE { public uint Version; public uint ControlMask; public uint StateMask; }
    public static int GetEco(int pid) {
        IntPtr h = OpenProcess(0x0400, false, pid);
        if (h == IntPtr.Zero) return -1;
        try {
            PROCESS_POWER_THROTTLING_STATE s = new PROCESS_POWER_THROTTLING_STATE();
            s.Version = 1; s.ControlMask = 0; s.StateMask = 0;
            if (!GetProcessInformation(h, 4, out s, (uint)Marshal.SizeOf(typeof(PROCESS_POWER_THROTTLING_STATE)))) return -2;
            return (int)s.StateMask;
        } finally { CloseHandle(h); }
    }
}
"@

function Get-AceEcoText {
    param([int]$ProcId)
    try {
        $m = [ProcThrottleProbe]::GetEco($ProcId)
        switch ($m) {
            1       { return (Get-UiText 'K0433') }
            0       { return (Get-UiText 'K0434') }
            -1      { return (Get-UiText 'K0435') }
            -2      { return (Get-UiText 'K0436') }
            default { return "StateMask=$m" }
        }
    } catch { return (Get-UiText 'K0437') }
}

function Show-AceState {
    param([string]$Tag)
    Write-Host ("  ----- {0} -----" -f $Tag) -ForegroundColor DarkGray
    $ps = @(Get-AceProcesses)
    if ($ps.Count -eq 0) { Write-Host (Get-UiText 'K0438') -ForegroundColor Yellow; return }
    foreach ($q in $ps) {
        Write-Host ((Get-UiText 'K0439') -f $q.ProcessName, $q.Id, $q.PriorityClass, (Get-AceEcoText $q.Id))
    }
}

function Start-AceWatchdog {
    param([int]$IntervalSec = 14)

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ((Get-UiText 'K0440') -f $IntervalSec) -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host (Get-UiText 'K0441') -ForegroundColor DarkGray
    Write-Host (Get-UiText 'K0442') -ForegroundColor DarkGray
    if (-not (Test-IsAdmin)) {
        Write-Host (Get-UiText 'K0443') -ForegroundColor Yellow
    }
    Log ((Get-UiText 'K0444') -f $IntervalSec)

    $emptyTick = 0
    $warned = @{}
    $fixed = 0

    $canKey   = $true
    $oldTreat = $false
    try {
        $oldTreat = [Console]::TreatControlCAsInput
        [Console]::TreatControlCAsInput = $true
    } catch { $canKey = $false }

    $stop = $false
    $acc  = $IntervalSec
    try {
        while (-not $stop) {
            if ($canKey) {
                try {
                    while ([Console]::KeyAvailable) {
                        $k = [Console]::ReadKey($true)
                        if (($k.Modifiers -band [ConsoleModifiers]::Control) -and ($k.Key -eq [ConsoleKey]::C)) {
                            $stop = $true
                            break
                        }
                    }
                } catch {
                    $canKey = $false
                    try { [Console]::TreatControlCAsInput = $oldTreat } catch { }
                }
            }
            if ($stop) { break }

            if ($canKey) { Start-Sleep -Seconds 1 } else { Start-Sleep -Seconds $IntervalSec }
            $acc++
            if ($acc -lt $IntervalSec) { continue }
            $acc = 0

            $procs = @(Get-AceProcesses)
            if ($procs.Count -eq 0) {
                $emptyTick++
                if ($emptyTick -eq 1 -or ($emptyTick % 10 -eq 0)) {
                    Write-Host ((Get-UiText 'K0447') -f (Get-Date -Format 'HH:mm:ss')) -ForegroundColor DarkGray
                }
                continue
            }
            $emptyTick = 0

            foreach ($p in $procs) {
                $eco = Get-AceEcoText $p.Id
                $prio = (Get-UiText 'K0448')
                try { $prio = [string]$p.PriorityClass } catch { }
                if ($eco -eq (Get-UiText 'K0433') -and $prio -eq 'Idle') {
                    if ($warned.ContainsKey($p.Id)) { $warned.Remove($p.Id) }
                    continue
                }
                $ok = $false
                try { $ok = [ProcThrottle]::SetEco($p.Id, $true) } catch { Log ((Get-UiText 'K0449') + $_.Exception.Message) }
                if ($ok) {
                    try { $p.PriorityClass = 'Idle' } catch { }
                    $fixed++
                    Write-Host ((Get-UiText 'K0450') -f (Get-Date -Format 'HH:mm:ss'), $p.ProcessName, $p.Id, $eco, $prio) -ForegroundColor Green
                    Log ((Get-UiText 'K0451') -f $p.ProcessName, $p.Id)
                } else {
                    if (-not $warned.ContainsKey($p.Id)) {
                        $warned[$p.Id] = $true
                        Write-Host ((Get-UiText 'K0452') -f (Get-Date -Format 'HH:mm:ss'), $p.ProcessName, $p.Id, $eco) -ForegroundColor Yellow
                        Log ((Get-UiText 'K0453') -f $p.ProcessName, $p.Id, $eco)
                    }
                }
            }
        }
    } finally {
        try { [Console]::TreatControlCAsInput = $oldTreat } catch { }
    }

    Write-Host ""
    Write-Host ((Get-UiText 'K0454') -f $fixed) -ForegroundColor Cyan
    Log ((Get-UiText 'K0455') -f $fixed)
}

function Invoke-AceSelfTest {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host (Get-UiText 'K0456') -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ((Get-UiText 'K0457') -f ($AceProcNames -join ', '))
    Write-Host ((Get-UiText 'K0458') -f $(if (Test-IsAdmin) { (Get-UiText 'K0459') } else { (Get-UiText 'K0460') }))

    $procs = @(Get-AceProcesses)
    if ($procs.Count -eq 0) {
        Write-Host ""
        Write-Host (Get-UiText 'K0070') -ForegroundColor Yellow
        Log (Get-UiText 'K0071')
        return
    }
    $total = $procs.Count
    Write-Host ""
    Write-Host ((Get-UiText 'K0461') -f $total, (($procs | ForEach-Object { $_.ProcessName + '(PID ' + $_.Id + ')' }) -join ', ')) -ForegroundColor Cyan
    Write-Host ""
    Show-AceState (Get-UiText 'K0462')

    Write-Host ""
    Write-Host (Get-UiText 'K0463') -ForegroundColor Cyan
    $failOn = @()
    foreach ($p in $procs) {
        $ok = $false
        try { $ok = [ProcThrottle]::SetEco($p.Id, $true) } catch { Log ((Get-UiText 'K0464') + $_.Exception.Message) }
        if ($ok) {
            try { $p.PriorityClass = 'Idle' } catch { Log ((Get-UiText 'K0465') + $p.ProcessName) }
        } else { $failOn += $p }
    }
    Show-AceState (Get-UiText 'K0466')
    $onOk = @($procs | Where-Object { (Get-AceEcoText $_.Id) -eq (Get-UiText 'K0433') }).Count

    Write-Host ""
    Write-Host (Get-UiText 'K0467') -ForegroundColor Cyan
    foreach ($p in $procs) {
        try { [ProcThrottle]::SetEco($p.Id, $false) | Out-Null } catch { Log ((Get-UiText 'K0468') + $_.Exception.Message) }
        try { $p.PriorityClass = 'Normal' } catch { }
    }
    Show-AceState (Get-UiText 'K0469')
    $offOk = @($procs | Where-Object { (Get-AceEcoText $_.Id) -eq (Get-UiText 'K0434') }).Count

    $r1 = ($total -gt 0)
    $r2 = ($onOk  -eq $total)
    $r3 = ($offOk -eq $total)
    $pass = ($r1 -and $r2 -and $r3)
    Write-Host ""
    Write-Host (Get-UiText 'K0470') -ForegroundColor Cyan
    Write-Host ((Get-UiText 'K0471') -f $(if ($r1) { (Get-UiText 'K0472') } else { (Get-UiText 'K0473') }), $total, $total) -ForegroundColor $(if ($r1) { 'Green' } else { 'Red' })
    Write-Host ((Get-UiText 'K0474') -f $(if ($r2) { (Get-UiText 'K0472') } else { (Get-UiText 'K0473') }), $onOk,  $total) -ForegroundColor $(if ($r2) { 'Green' } else { 'Red' })
    Write-Host ((Get-UiText 'K0475') -f $(if ($r3) { (Get-UiText 'K0472') } else { (Get-UiText 'K0473') }), $offOk, $total) -ForegroundColor $(if ($r3) { 'Green' } else { 'Red' })
    Write-Host ""
    if ($pass) {
        Write-Host (Get-UiText 'K0476') -ForegroundColor Green
    } else {
        Write-Host (Get-UiText 'K0477') -ForegroundColor Red
    }
    if ($failOn.Count -gt 0) { Write-AdminHint }

    Write-Host ""
    $ans = 'N'
    try { $ans = [string](Read-Host (Get-UiText 'K0478')) } catch { $ans = 'N'; Log (Get-UiText 'K0479') }
    if ($ans -eq 'Y' -or $ans -eq 'y') {
        Write-Host ""
        Write-Host (Get-UiText 'K0480') -ForegroundColor Cyan
        foreach ($p in $procs) {
            try { [ProcThrottle]::SetEco($p.Id, $true) | Out-Null } catch { Log ((Get-UiText 'K0481') + $_.Exception.Message) }
            try { $p.PriorityClass = 'Idle' } catch { }
        }
        Show-AceState (Get-UiText 'K0482')

        Write-Host ""
        $wd = 'N'
        try { $wd = [string](Read-Host (Get-UiText 'K0483')) } catch { $wd = 'N'; Log (Get-UiText 'K0484') }
        if ($wd -eq 'Y' -or $wd -eq 'y') {
            Log ((Get-UiText 'K0485') -f $total, $onOk, $offOk, $(if ($pass) { (Get-UiText 'K0472') } else { (Get-UiText 'K0473') }))
            Start-AceWatchdog -IntervalSec 14
        } else {
            Write-Host ""
            Write-Host (Get-UiText 'K0486') -ForegroundColor DarkGray
            Write-Host (Get-UiText 'K0076') -ForegroundColor DarkGray
            Log ((Get-UiText 'K0487') -f $total, $onOk, $offOk, $(if ($pass) { (Get-UiText 'K0472') } else { (Get-UiText 'K0473') }))
        }
    } else {
        Write-Host ""
        Write-Host (Get-UiText 'K0488') -ForegroundColor DarkGray
        Log ((Get-UiText 'K0489') -f $total, $onOk, $offOk, $(if ($pass) { (Get-UiText 'K0472') } else { (Get-UiText 'K0473') }))
    }
}


Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class IcmHelper {
    [DllImport("gdi32.dll", CharSet=CharSet.Unicode)]
    public static extern IntPtr CreateDCW(string driver, string device, string port, IntPtr devmode);
    [DllImport("gdi32.dll", CharSet=CharSet.Unicode)]
    public static extern bool GetICMProfileW(IntPtr hdc, ref uint size, StringBuilder name);
    [DllImport("gdi32.dll", CharSet=CharSet.Unicode)]
    public static extern bool SetICMProfileW(IntPtr hdc, string name);
    [DllImport("gdi32.dll")]
    public static extern bool SetDeviceGammaRamp(IntPtr hdc, ushort[] ramp);
    [DllImport("gdi32.dll")]
    public static extern bool DeleteDC(IntPtr hdc);
}
"@

$IccDir          = Join-Path $PSScriptRoot 'ICCFilter'

function Get-IccOriginal {
    $rv = Get-ItemProperty $SettingsRegKey -Name 'IccOrig' -ErrorAction SilentlyContinue
    if ($rv -and $rv.IccOrig) { return [string]$rv.IccOrig }
    return $null
}

function Set-IccOriginal([string]$p) {
    try {
        if (-not (Test-Path $SettingsRegKey)) { New-Item -Path $SettingsRegKey -Force | Out-Null }
        New-ItemProperty -Path $SettingsRegKey -Name 'IccOrig' -Value $p -PropertyType String -Force | Out-Null
    } catch {}
}

$IccPresets = @(
    [pscustomobject]@{ Key='C1'; Kind='Curve'; Group=(Get-UiText 'K0316'); File=(Get-UiText 'K0171');    Name='DF Filter - Standard sRGB';  Gamma=2.20; Lift=0.000; Contrast=1.00; Gain=@(1.00,1.00,1.00); Desc=(Get-UiText 'K0172') },
    [pscustomobject]@{ Key='C2'; Kind='Curve'; Group=(Get-UiText 'K0316'); File=(Get-UiText 'K0173');    Name='DF Filter - Esport Cool';    Gamma=1.95; Lift=0.015; Contrast=1.08; Gain=@(0.97,1.00,1.06); Desc=(Get-UiText 'K0174') },
    [pscustomobject]@{ Key='C3'; Kind='Curve'; Group=(Get-UiText 'K0316'); File=(Get-UiText 'K0175'); Name='DF Filter - Shadow Lift';    Gamma=1.65; Lift=0.050; Contrast=1.06; Gain=@(1.00,1.00,1.03); Desc=(Get-UiText 'K0176') },
    [pscustomobject]@{ Key='C4'; Kind='Curve'; Group=(Get-UiText 'K0316'); File=(Get-UiText 'K0177');    Name='DF Filter - Streamer Warm';  Gamma=2.10; Lift=0.000; Contrast=1.16; Gain=@(1.05,1.00,0.94); Desc=(Get-UiText 'K0178') },
    [pscustomobject]@{ Key='C5'; Kind='Curve'; Group=(Get-UiText 'K0316'); File=(Get-UiText 'K0179');   Name='DF Filter - Max Contrast';   Gamma=2.00; Lift=0.000; Contrast=1.22; Gain=@(1.00,1.00,1.00); Desc=(Get-UiText 'K0180') }
)

$LutPresets = @(
    [pscustomobject]@{ Key='L1'; Kind='Lut'; Group=(Get-UiText 'K0317'); File=(Get-UiText 'K0320'); Name='LUT Filter - MingJi'; Gamma=2.20; Desc=(Get-UiText 'K0321'); Ramp=@(@(0.0000,0.0086,0.0545,0.1115,0.1673,0.2214,0.2738,0.3245,0.3739,0.4219,0.4691,0.5155,0.5614,0.6072,0.6530,0.6990,0.7456,0.7927,0.8405,0.8891,0.9380,0.9838,1.0000,1.0000,1.0000),@(0.0000,0.0079,0.0513,0.1076,0.1632,0.2171,0.2694,0.3201,0.3695,0.4177,0.4651,0.5118,0.5581,0.6043,0.6505,0.6970,0.7440,0.7915,0.8397,0.8885,0.9377,0.9837,1.0000,1.0000,1.0000),@(0.0000,0.0081,0.0521,0.1086,0.1642,0.2182,0.2705,0.3212,0.3706,0.4188,0.4661,0.5127,0.5589,0.6050,0.6511,0.6975,0.7444,0.7918,0.8399,0.8887,0.9377,0.9837,1.0000,1.0000,1.0000)) },
    [pscustomobject]@{ Key='L2'; Kind='Lut'; Group=(Get-UiText 'K0317'); File=(Get-UiText 'K0322'); Name='LUT Filter - Cinema'; Gamma=2.20; Desc=(Get-UiText 'K0323'); Ramp=@(@(0.0000,0.0310,0.0879,0.1437,0.1983,0.2517,0.3039,0.3547,0.4043,0.4529,0.5006,0.5475,0.5940,0.6402,0.6863,0.7326,0.7791,0.8259,0.8731,0.9207,0.9686,1.0000,1.0000,1.0000,1.0000),@(0.0000,0.0310,0.0879,0.1437,0.1983,0.2517,0.3039,0.3547,0.4043,0.4529,0.5006,0.5475,0.5940,0.6402,0.6863,0.7326,0.7791,0.8259,0.8731,0.9207,0.9686,1.0000,1.0000,1.0000,1.0000),@(0.0000,0.0310,0.0879,0.1437,0.1983,0.2517,0.3039,0.3547,0.4043,0.4529,0.5006,0.5475,0.5940,0.6402,0.6863,0.7326,0.7791,0.8259,0.8731,0.9207,0.9686,1.0000,1.0000,1.0000,1.0000)) },
    [pscustomobject]@{ Key='L3'; Kind='Lut'; Group=(Get-UiText 'K0317'); File=(Get-UiText 'K0324'); Name='LUT Filter - Soft'; Gamma=2.20; Desc=(Get-UiText 'K0325'); Ramp=@(@(0.0000,0.0409,0.0992,0.1516,0.2001,0.2474,0.2958,0.3408,0.3784,0.4116,0.4442,0.4796,0.5208,0.5614,0.5962,0.6294,0.6645,0.7044,0.7509,0.7939,0.8305,0.8693,0.9161,0.9706,1.0000),@(0.0000,0.0409,0.0992,0.1516,0.2001,0.2474,0.2958,0.3408,0.3784,0.4116,0.4442,0.4796,0.5208,0.5614,0.5962,0.6294,0.6645,0.7044,0.7509,0.7939,0.8305,0.8693,0.9161,0.9706,1.0000),@(0.0000,0.0409,0.0992,0.1516,0.2001,0.2474,0.2958,0.3408,0.3784,0.4116,0.4442,0.4796,0.5208,0.5614,0.5962,0.6294,0.6645,0.7044,0.7509,0.7939,0.8305,0.8693,0.9161,0.9706,1.0000)) },
    [pscustomobject]@{ Key='L4'; Kind='Lut'; Group=(Get-UiText 'K0317'); File=(Get-UiText 'K0326'); Name='LUT Filter - AntiGlare'; Gamma=2.20; Desc=(Get-UiText 'K0327'); Ramp=@(@(0.0000,0.0419,0.0924,0.1339,0.1692,0.2005,0.2296,0.2582,0.2881,0.3204,0.3529,0.3852,0.4171,0.4486,0.4797,0.5105,0.5408,0.5707,0.5970,0.6162,0.6312,0.6446,0.6588,0.6759,0.6976),@(0.0000,0.0419,0.0924,0.1339,0.1692,0.2005,0.2296,0.2582,0.2881,0.3204,0.3529,0.3852,0.4171,0.4486,0.4797,0.5105,0.5408,0.5707,0.5970,0.6162,0.6312,0.6446,0.6588,0.6759,0.6976),@(0.0000,0.0419,0.0924,0.1339,0.1692,0.2005,0.2296,0.2582,0.2881,0.3204,0.3529,0.3852,0.4171,0.4486,0.4797,0.5105,0.5408,0.5707,0.5970,0.6162,0.6312,0.6446,0.6588,0.6759,0.6976)) },
    [pscustomobject]@{ Key='L5'; Kind='Lut'; Group=(Get-UiText 'K0317'); File=(Get-UiText 'K0328'); Name='LUT Filter - Bright'; Gamma=2.20; Desc=(Get-UiText 'K0329'); Ramp=@(@(0.0000,0.0682,0.1544,0.2266,0.2894,0.3418,0.3856,0.4245,0.4614,0.4982,0.5357,0.5656,0.5899,0.6129,0.6378,0.6673,0.7031,0.7417,0.7696,0.7940,0.8222,0.8603,0.9120,0.9727,1.0000),@(0.0000,0.0682,0.1544,0.2266,0.2894,0.3418,0.3856,0.4245,0.4614,0.4982,0.5357,0.5656,0.5899,0.6129,0.6378,0.6673,0.7031,0.7417,0.7696,0.7940,0.8222,0.8603,0.9120,0.9727,1.0000),@(0.0000,0.0682,0.1544,0.2266,0.2894,0.3418,0.3856,0.4245,0.4614,0.4982,0.5357,0.5656,0.5899,0.6129,0.6378,0.6673,0.7031,0.7417,0.7696,0.7940,0.8222,0.8603,0.9120,0.9727,1.0000)) },
    [pscustomobject]@{ Key='L6'; Kind='Lut'; Group=(Get-UiText 'K0317'); File=(Get-UiText 'K0330'); Name='LUT Filter - Vivid'; Gamma=2.20; Desc=(Get-UiText 'K0331'); Ramp=@(@(0.0000,0.0136,0.0479,0.0945,0.1455,0.1973,0.2485,0.2995,0.3508,0.4022,0.4538,0.5057,0.5572,0.6078,0.6587,0.7106,0.7639,0.8181,0.8718,0.9238,0.9694,1.0000,1.0000,1.0000,1.0000),@(0.0000,0.0136,0.0479,0.0945,0.1455,0.1973,0.2485,0.2995,0.3508,0.4022,0.4538,0.5057,0.5572,0.6078,0.6587,0.7106,0.7639,0.8181,0.8718,0.9238,0.9694,1.0000,1.0000,1.0000,1.0000),@(0.0000,0.0136,0.0479,0.0945,0.1455,0.1973,0.2485,0.2995,0.3508,0.4022,0.4538,0.5057,0.5572,0.6078,0.6587,0.7106,0.7639,0.8181,0.8718,0.9238,0.9694,1.0000,1.0000,1.0000,1.0000)) },
    [pscustomobject]@{ Key='L7'; Kind='Lut'; Group=(Get-UiText 'K0317'); File=(Get-UiText 'K0332'); Name='LUT Filter - Daylight'; Gamma=2.20; Desc=(Get-UiText 'K0333'); Ramp=@(@(0.0000,0.0500,0.1167,0.1804,0.2407,0.2974,0.3502,0.3993,0.4448,0.4869,0.5262,0.5630,0.5980,0.6315,0.6642,0.6965,0.7288,0.7614,0.7947,0.8287,0.8636,0.8991,0.9351,0.9704,0.9990),@(0.0000,0.0478,0.1144,0.1780,0.2382,0.2947,0.3476,0.3966,0.4421,0.4843,0.5237,0.5607,0.5958,0.6295,0.6624,0.6949,0.7274,0.7603,0.7938,0.8281,0.8631,0.8988,0.9349,0.9703,0.9990),@(0.0000,0.0535,0.1204,0.1843,0.2447,0.3015,0.3545,0.4036,0.4490,0.4911,0.5302,0.5669,0.6015,0.6348,0.6671,0.6990,0.7309,0.7632,0.7961,0.8298,0.8644,0.8997,0.9354,0.9705,0.9990)) }
)

$AllPresets = @($IccPresets) + @($LutPresets)
$FilterOrderFile = Join-Path $PSScriptRoot 'filterorder.json'

function Get-U32BE([uint32]$v) { [byte[]]@([byte](($v -shr 24) -band 0xFF), [byte](($v -shr 16) -band 0xFF), [byte](($v -shr 8) -band 0xFF), [byte]($v -band 0xFF)) }
function Get-U16BE([uint16]$v) { [byte[]]@([byte](($v -shr 8) -band 0xFF), [byte]($v -band 0xFF)) }
function Get-S15BE([double]$d) { Get-U32BE ([uint32][math]::Round($d * 65536)) }
function Get-Sig([string]$s)   { [System.Text.Encoding]::ASCII.GetBytes($s.PadRight(4).Substring(0,4)) }
function Get-Zeros([int]$n)    { [byte[]]((1..$n) | ForEach-Object { [byte]0 }) }

function New-LutRamp($preset) {
    $luts = @()
    foreach ($ch in 0..2) {
        $src = $preset.Ramp[$ch]
        $sn  = $src.Count
        $t = New-Object 'System.UInt16[]' 256
        for ($i = 0; $i -lt 256; $i++) {
            $x = ($i / 255.0) * ($sn - 1)
            $k = [int][math]::Floor($x)
            if ($k -ge ($sn - 1)) { $k = $sn - 2; $f = 1.0 } else { $f = $x - $k }
            $v = [double]$src[$k] + ([double]$src[$k + 1] - [double]$src[$k]) * $f
            if ($v -lt 0) { $v = 0 }
            if ($v -gt 1) { $v = 1 }
            $t[$i] = [uint16][math]::Round($v * 65535)
        }
        $luts += ,$t
    }
    return ,$luts
}

function New-PresetLut($preset) {
    if ($preset.Kind -eq 'Lut') { return (New-LutRamp $preset) }
    $luts = @()
    foreach ($ch in 0..2) {
        $t = New-Object 'System.UInt16[]' 256
        for ($i = 0; $i -lt 256; $i++) {
            $v = $i / 255.0
            $v = [math]::Pow($v, 1.0 / $preset.Gamma)
            $v = ($v - 0.5) * $preset.Contrast + 0.5
            $v = $preset.Lift + $v * (1.0 - $preset.Lift)
            $v = $v * $preset.Gain[$ch]
            if ($v -lt 0) { $v = 0 }
            if ($v -gt 1) { $v = 1 }
            $t[$i] = [uint16][math]::Round($v * 65535)
        }
        $luts += ,$t
    }
    return ,$luts
}

function New-IccProfile {
    param([string]$Name, [uint16[]]$R, [uint16[]]$G, [uint16[]]$B, [double]$Gamma)

    $tags = New-Object System.Collections.ArrayList

    $ascii = [System.Text.Encoding]::ASCII.GetBytes($Name + [char]0)
    $d = New-Object System.Collections.Generic.List[byte]
    $d.AddRange([byte[]](Get-Sig 'desc')); $d.AddRange([byte[]](Get-Zeros 4))
    $d.AddRange([byte[]](Get-U32BE ([uint32]$ascii.Length))); $d.AddRange([byte[]]$ascii)
    $d.AddRange([byte[]](Get-Zeros 4)); $d.AddRange([byte[]](Get-Zeros 4))
    $d.AddRange([byte[]](Get-Zeros 2)); $d.AddRange([byte[]](Get-Zeros 1)); $d.AddRange([byte[]](Get-Zeros 67))
    $tags.Add(@{ Sig='desc'; Data=$d.ToArray() }) | Out-Null

    $cp = [System.Text.Encoding]::ASCII.GetBytes($AppName + [char]0)
    $d = New-Object System.Collections.Generic.List[byte]
    $d.AddRange([byte[]](Get-Sig 'text')); $d.AddRange([byte[]](Get-Zeros 4)); $d.AddRange([byte[]]$cp)
    $tags.Add(@{ Sig='cprt'; Data=$d.ToArray() }) | Out-Null

    $d = New-Object System.Collections.Generic.List[byte]
    $d.AddRange([byte[]](Get-Sig 'XYZ ')); $d.AddRange([byte[]](Get-Zeros 4))
    $d.AddRange([byte[]](Get-S15BE 0)); $d.AddRange([byte[]](Get-S15BE 1)); $d.AddRange([byte[]](Get-S15BE 0))
    $tags.Add(@{ Sig='wtpt'; Data=$d.ToArray() }) | Out-Null

    foreach ($p in @(@('rXYZ',0.4360,0.2225,0.0139), @('gXYZ',0.3851,0.7169,0.0971), @('bXYZ',0.1431,0.0606,0.7141))) {
        $d = New-Object System.Collections.Generic.List[byte]
        $d.AddRange([byte[]](Get-Sig $p[0])); $d.AddRange([byte[]](Get-Zeros 4))
        $d.AddRange([byte[]](Get-S15BE $p[1])); $d.AddRange([byte[]](Get-S15BE $p[2])); $d.AddRange([byte[]](Get-S15BE $p[3]))
        $tags.Add(@{ Sig=$p[0]; Data=$d.ToArray() }) | Out-Null
    }

    $d = New-Object System.Collections.Generic.List[byte]
    $d.AddRange([byte[]](Get-Sig 'curv')); $d.AddRange([byte[]](Get-Zeros 4))
    $d.AddRange([byte[]](Get-U32BE 1))
    $d.AddRange([byte[]](Get-U16BE ([uint16][math]::Round($Gamma * 256))))
    $tags.Add(@{ Sig='rTRC'; Data=$d.ToArray() }) | Out-Null
    $tags.Add(@{ Sig='gTRC'; Data=$d.ToArray() }) | Out-Null
    $tags.Add(@{ Sig='bTRC'; Data=$d.ToArray() }) | Out-Null

    $d = New-Object System.Collections.Generic.List[byte]
    $d.AddRange([byte[]](Get-Sig 'vcgt')); $d.AddRange([byte[]](Get-Zeros 4))
    foreach ($tbl in @($R, $G, $B)) {
        $d.AddRange([byte[]](Get-U16BE 0)); $d.AddRange([byte[]](Get-U16BE 256)); $d.AddRange([byte[]](Get-U16BE 2))
        for ($i = 0; $i -lt 256; $i++) { $d.AddRange([byte[]](Get-U16BE $tbl[$i])) }
    }
    $tags.Add(@{ Sig='vcgt'; Data=$d.ToArray() }) | Out-Null

    $table = New-Object System.Collections.Generic.List[byte]
    $data  = New-Object System.Collections.Generic.List[byte]
    $table.AddRange([byte[]](Get-U32BE ([uint32]$tags.Count)))
    $offset = 128 + 4 + 12 * $tags.Count
    foreach ($t in $tags) {
        $size = $t.Data.Length
        $table.AddRange([byte[]](Get-Sig $t.Sig))
        $table.AddRange([byte[]](Get-U32BE ([uint32]$offset)))
        $table.AddRange([byte[]](Get-U32BE ([uint32]$size)))
        $data.AddRange([byte[]]$t.Data)
        $pad = (4 - ($size % 4)) % 4
        if ($pad -gt 0) { $data.AddRange([byte[]](Get-Zeros $pad)) }
        $offset += $size + $pad
    }
    $profileSize = 128 + $table.Count + $data.Count

    $now = Get-Date
    $h = New-Object System.Collections.Generic.List[byte]
    $h.AddRange([byte[]](Get-U32BE ([uint32]$profileSize)))
    $h.AddRange([byte[]](Get-Sig 'none'))
    $h.AddRange([byte[]](Get-U32BE 0x02100000))
    $h.AddRange([byte[]](Get-Sig 'mntr'))
    $h.AddRange([byte[]](Get-Sig 'RGB '))
    $h.AddRange([byte[]](Get-Sig 'XYZ '))            # PCS
    $h.AddRange([byte[]](Get-U16BE ([uint16]$now.Year))); $h.AddRange([byte[]](Get-U16BE ([uint16]$now.Month)))
    $h.AddRange([byte[]](Get-U16BE ([uint16]$now.Day)));  $h.AddRange([byte[]](Get-U16BE ([uint16]$now.Hour)))
    $h.AddRange([byte[]](Get-U16BE ([uint16]$now.Minute))); $h.AddRange([byte[]](Get-U16BE ([uint16]$now.Second)))
    $h.AddRange([byte[]](Get-Sig 'acsp'))
    $h.AddRange([byte[]](Get-Sig 'MSFT'))
    $h.AddRange([byte[]](Get-U32BE 1))
    $h.AddRange([byte[]](Get-Sig 'none'))
    $h.AddRange([byte[]](Get-U32BE 0))
    $h.AddRange([byte[]](Get-Zeros 8))
    $h.AddRange([byte[]](Get-U32BE 0))
    $h.AddRange([byte[]](Get-S15BE 0.9642)); $h.AddRange([byte[]](Get-S15BE 1.0)); $h.AddRange([byte[]](Get-S15BE 0.8249))
    $h.AddRange([byte[]](Get-Sig 'none'))
    $h.AddRange([byte[]](Get-Zeros 16))              # profile ID
    $h.AddRange([byte[]](Get-Zeros 28))

    return [byte[]]($h.ToArray() + $table.ToArray() + $data.ToArray())
}

function Invoke-IccApply {
    param($preset)
    if (-not (Test-Path $IccDir)) { New-Item -ItemType Directory -Path $IccDir | Out-Null }
    $luts = New-PresetLut $preset
    $iccPath = Join-Path $IccDir ($preset.File + '.icc')
    try {
        $bytes = New-IccProfile -Name $preset.Name -R $luts[0] -G $luts[1] -B $luts[2] -Gamma $preset.Gamma
        [System.IO.File]::WriteAllBytes($iccPath, $bytes)
        Log ((Get-UiText 'K0085') -f $iccPath, $bytes.Length)
    } catch {
        Write-Host ((Get-UiText 'K0086') -f $_.Exception.Message) -ForegroundColor Red
        Log ((Get-UiText 'K0087') + $_.Exception.Message)
        return
    }

    $hdc = [IcmHelper]::CreateDCW('DISPLAY', $null, $null, [IntPtr]::Zero)
    if ($hdc -eq [IntPtr]::Zero) {
        Write-Host (Get-UiText 'K0088') -ForegroundColor Red
        return
    }
    try {
        $sz = [uint32]520
        $sb = New-Object System.Text.StringBuilder 520
        if ([IcmHelper]::GetICMProfileW($hdc, [ref]$sz, $sb)) {
            $orig = $sb.ToString()
            if ($orig -and -not (Get-IccOriginal)) {
                Set-IccOriginal $orig
                Log ((Get-UiText 'K0089') + $orig)
            }
        }
        $ramp = New-Object 'System.UInt16[]' 768
        for ($i = 0; $i -lt 256; $i++) { $ramp[$i] = $luts[0][$i]; $ramp[256 + $i] = $luts[1][$i]; $ramp[512 + $i] = $luts[2][$i] }
        $okRamp = [IcmHelper]::SetDeviceGammaRamp($hdc, $ramp)
        $okProf = [IcmHelper]::SetICMProfileW($hdc, $iccPath)
        if ($okRamp) {
            Write-Host ((Get-UiText 'K0090') -f $preset.Desc, $preset.Name) -ForegroundColor Green
            Log ((Get-UiText 'K0091') -f $preset.File, $okRamp, $okProf)
        } else {
            Write-Host (Get-UiText 'K0092') -ForegroundColor Red
            Log (Get-UiText 'K0093')
        }
    } finally {
        [IcmHelper]::DeleteDC($hdc) | Out-Null
    }
    Write-Host (Get-UiText 'K0094') -ForegroundColor DarkGray
}

function Invoke-IccRestore {
    $hdc = [IcmHelper]::CreateDCW('DISPLAY', $null, $null, [IntPtr]::Zero)
    if ($hdc -eq [IntPtr]::Zero) { Write-Host (Get-UiText 'K0095') -ForegroundColor Red; return }
    try {
        $ramp = New-Object 'System.UInt16[]' 768
        for ($i = 0; $i -lt 256; $i++) { $v = [uint16]($i * 257); $ramp[$i] = $v; $ramp[256 + $i] = $v; $ramp[512 + $i] = $v }
        $okRamp = [IcmHelper]::SetDeviceGammaRamp($hdc, $ramp)
        $okProf = $true
        $orig = Get-IccOriginal
        if ($orig) { $okProf = [IcmHelper]::SetICMProfileW($hdc, $orig) }
        if ($okRamp) {
            Write-Host (Get-UiText 'K0096') -ForegroundColor Green
            Log ((Get-UiText 'K0097') -f $okProf)
        } else {
            Write-Host (Get-UiText 'K0098') -ForegroundColor Red
        }
    } finally {
        [IcmHelper]::DeleteDC($hdc) | Out-Null
    }
}

function Get-OrderedPresets {
    $order = $null
    if (Test-Path $FilterOrderFile) {
        try {
            $txt = [System.IO.File]::ReadAllText($FilterOrderFile)
            if ($txt) {
                $parsed = ConvertFrom-Json $txt
                if ($null -ne $parsed) { $order = @($parsed) }
            }
        } catch { $order = $null }
    }
    $map = @{}
    foreach ($p in $AllPresets) { $map[$p.Key] = $p }
    $list = New-Object System.Collections.ArrayList
    if ($order) {
        foreach ($k in $order) {
            $kk = [string]$k
            if ($map.ContainsKey($kk) -and -not $list.Contains($map[$kk])) { $list.Add($map[$kk]) | Out-Null }
        }
    }
    foreach ($p in $AllPresets) { if (-not $list.Contains($p)) { $list.Add($p) | Out-Null } }
    return ,$list
}

function Save-FilterOrder($list) {
    try {
        $keys = @($list | ForEach-Object { $_.Key })
        [System.IO.File]::WriteAllText($FilterOrderFile, (ConvertTo-Json @($keys)), (New-Object System.Text.UTF8Encoding($false)))
        return $true
    } catch {
        return $false
    }
}

function Read-MenuChoice([string]$prompt) {
    try { return [string](Read-Host $prompt) } catch { return 'Q' }
}

function Invoke-FilterSort {
    $list = Get-OrderedPresets
    while ($true) {
        Write-Host ""
        Write-Host (Get-UiText 'K0306') -ForegroundColor Cyan
        $lastGroup = ''
        for ($i = 0; $i -lt $list.Count; $i++) {
            $g = [string]$list[$i].Group
            if ($g -ne $lastGroup) {
                Write-Host ""
                Write-Host ((Get-UiText 'K0335') -f $g) -ForegroundColor DarkCyan
                $lastGroup = $g
            }
            Write-Host ((Get-UiText 'K0334') -f ($i + 1), $list[$i].File, $list[$i].Desc)
        }
        Write-Host (Get-UiText 'K0307') -ForegroundColor DarkGray
        $c = Read-MenuChoice (Get-UiText 'K0314')
        if (-not $c) { $c = 'Q' }
        if ($c -eq 'Q' -or $c -eq 'q') { return }
        if ($c -eq 'R' -or $c -eq 'r') {
            if (Test-Path $FilterOrderFile) { Remove-Item $FilterOrderFile -Force -ErrorAction SilentlyContinue }
            Write-Host (Get-UiText 'K0309') -ForegroundColor Green
            $list = Get-OrderedPresets
            continue
        }
        $idx = 0
        if (-not ([int]::TryParse($c, [ref]$idx)) -or $idx -lt 1 -or $idx -gt $list.Count) {
            Write-Host (Get-UiText 'K0103') -ForegroundColor Yellow
            continue
        }
        $a = Read-MenuChoice (Get-UiText 'K0315')
        if (-not $a) { $a = 'Q' }
        $moved = $false
        switch -Regex ($a.ToUpper()) {
            '^U' {
                if ($idx -gt 1) {
                    $t = $list[$idx - 1]; $list[$idx - 1] = $list[$idx - 2]; $list[$idx - 2] = $t
                    $moved = $true
                    Write-Host ((Get-UiText 'K0311') -f $t.File) -ForegroundColor Green
                } else { Write-Host (Get-UiText 'K0310') -ForegroundColor Yellow }
            }
            '^D' {
                if ($idx -lt $list.Count) {
                    $t = $list[$idx - 1]; $list[$idx - 1] = $list[$idx]; $list[$idx] = $t
                    $moved = $true
                    Write-Host ((Get-UiText 'K0312') -f $t.File) -ForegroundColor Green
                } else { Write-Host (Get-UiText 'K0310') -ForegroundColor Yellow }
            }
            '^T' {
                if ($idx -gt 1) {
                    $t = $list[$idx - 1]; $list.RemoveAt($idx - 1); $list.Insert(0, $t)
                    $moved = $true
                    Write-Host ((Get-UiText 'K0313') -f $t.File) -ForegroundColor Green
                } else { Write-Host (Get-UiText 'K0310') -ForegroundColor Yellow }
            }
            default { Write-Host (Get-UiText 'K0103') -ForegroundColor Yellow }
        }
        if ($moved) {
            if (Save-FilterOrder $list) { Write-Host (Get-UiText 'K0308') -ForegroundColor Green }
            else { Write-Host (Get-UiText 'K0103') -ForegroundColor Yellow }
        }
    }
}

function Show-IccMenu {
    Write-Host ""
    Write-Host (Get-UiText 'K0301') -ForegroundColor Cyan
    $list = Get-OrderedPresets
    $lastGroup = ''
    for ($i = 0; $i -lt $list.Count; $i++) {
        $p = $list[$i]
        $g = [string]$p.Group
        if ($g -ne $lastGroup) {
            Write-Host ""
            Write-Host ((Get-UiText 'K0335') -f $g) -ForegroundColor DarkCyan
            $lastGroup = $g
        }
        Write-Host ((Get-UiText 'K0334') -f ($i + 1), $p.File, $p.Desc)
    }
    Write-Host ""
    Write-Host (Get-UiText 'K0319') -ForegroundColor DarkGray
    Write-Host (Get-UiText 'K0303') -ForegroundColor Yellow
    Write-Host (Get-UiText 'K0304')
    $c = Read-Host (Get-UiText 'K0305')
    if ($c -eq '0') { return }
    if ($c -eq 'S' -or $c -eq 's') { Invoke-FilterSort; return }
    $idx = 0
    if ([int]::TryParse($c, [ref]$idx) -and $idx -ge 1 -and $idx -le $list.Count) {
        Invoke-IccApply $list[$idx - 1]
    } else {
        Write-Host (Get-UiText 'K0103') -ForegroundColor Yellow
    }
}

$exit = $false
while (-not $exit) {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host (Get-UiText 'K0137') -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ((Get-UiText 'K0139') -f $SpoofName)
    Write-Host (Get-UiText 'K0141')
    Write-Host (Get-UiText 'K0142')
    Write-Host (Get-UiText 'K0143')
    Write-Host (Get-UiText 'K0144')
    Write-Host (Get-UiText 'K0145')
    Write-Host (Get-UiText 'K0146')
    Write-Host (Get-UiText 'K0149')
    Write-Host (Get-UiText 'K0150')
    Write-Host (Get-UiText 'K0151')
    Write-Host (Get-UiText 'K0154')
    Write-Host "==========================================================" -ForegroundColor Cyan
    $choice = Read-Host (Get-UiText 'K0157')
    switch ($choice) {
        '1' { Show-Current }
        '2' { Invoke-Spoof }
        '3' { Invoke-Restore }
        '4' { Show-IccMenu }
        '5' { Invoke-IccRestore }
        '6' { Invoke-AceSelfTest }
        '0' { $exit = $true }
        default { Write-Host (Get-UiText 'K0160') -ForegroundColor Yellow }
    }
}
