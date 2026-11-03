[CmdletBinding()]
param(
    [string]$Configuration = 'Release',
    [string]$ZigPath
)
$ErrorActionPreference = 'Stop'
$vsWhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsDev = if (Test-Path -LiteralPath $vsWhere) { & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | ForEach-Object { Join-Path $_ 'Common7\Tools\VsDevCmd.bat' } | Select-Object -First 1 } else { $null }
$defaultZig = Join-Path (Split-Path -Parent $PSScriptRoot) 'analysis\toolchain\zig-x86_64-windows-0.17.0\zig.exe'
if (-not $ZigPath -and (Test-Path -LiteralPath $defaultZig)) { $ZigPath = $defaultZig }
if (-not $ZigPath) { $zigCommand = Get-Command zig -ErrorAction SilentlyContinue; if ($zigCommand) { $ZigPath = $zigCommand.Source } }
$out = Join-Path $PSScriptRoot 'bin'
New-Item -ItemType Directory -Path $out -Force | Out-Null
if ($vsDev -and -not (Test-Path -LiteralPath $vsDev)) { $vsDev = $null }
if ($vsDev) {
    $cmd = 'call "' + $vsDev + '" -arch=x64 -host_arch=x64 >nul && cl.exe /nologo /std:c++17 /O2 /MT /EHsc /utf-8 /DUNICODE /D_UNICODE /Fo"' + (Join-Path $out 'DeltaOps.obj') + '" /Fe:"' + (Join-Path $out 'DeltaOps.exe') + '" "' + (Join-Path $PSScriptRoot 'main.cpp') + '" /link /SUBSYSTEM:WINDOWS user32.lib gdi32.lib shell32.lib comctl32.lib'
    cmd.exe /d /c $cmd
    if ($LASTEXITCODE -ne 0 -and $ZigPath) { $vsDev = $null }
    elseif ($LASTEXITCODE -ne 0) { throw 'C++ compilation failed.' }
}
if (-not $vsDev) {
    if (-not $ZigPath -or -not (Test-Path -LiteralPath $ZigPath)) { throw 'No C++ compiler found. Install the Visual Studio C++ workload or supply -ZigPath.' }
    & $ZigPath c++ -target x86_64-windows-gnu -std=c++17 -O2 -s -municode '-Wl,--subsystem,windows' -DUNICODE -D_UNICODE (Join-Path $PSScriptRoot 'main.cpp') -luser32 -lgdi32 -lshell32 -lcomctl32 -o (Join-Path $out 'DeltaOps.exe')
    if ($LASTEXITCODE -ne 0) { throw 'Zig C++ compilation failed.' }
}
$targetBackend = Join-Path $out 'backend'
New-Item -ItemType Directory -Force -Path $targetBackend | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'backend\GpuTool.i18n.ps1') -Destination $targetBackend -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'backend\Start-GpuTool.ps1') -Destination $targetBackend -Force
$sourceLocales = Join-Path $PSScriptRoot 'backend\locales'
$targetLocales = Join-Path $targetBackend 'locales'
New-Item -ItemType Directory -Force -Path $targetLocales | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceLocales 'en.json'),(Join-Path $sourceLocales 'vi.json') -Destination $targetLocales -Force
foreach ($runtimeFile in 'gpu_models.json','gpu_ui.json') { $source = Join-Path (Join-Path $PSScriptRoot 'backend') $runtimeFile; if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw ('Missing backend data: ' + $runtimeFile) }; Copy-Item -LiteralPath $source -Destination $targetBackend -Force }
Get-Item (Join-Path $out 'DeltaOps.exe') | Select-Object FullName,Length,LastWriteTime
