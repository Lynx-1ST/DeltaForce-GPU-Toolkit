# Choose a language before the selected utility requests Administrator access.
[CmdletBinding()]
param(
    [ValidateSet('en', 'vi')]
    [string]$Language
)

$ErrorActionPreference = 'Stop'

function Read-UiLanguage {
    while ($true) {
        Write-Host ''
        Write-Host '==========================================' -ForegroundColor Cyan
        Write-Host '  GPU Tool / Cong cu GPU' -ForegroundColor Cyan
        Write-Host '==========================================' -ForegroundColor Cyan
        Write-Host '  [1] English'
        Write-Host '  [2] Tieng Viet (khong dau)'
        Write-Host '  [0] Exit / Thoat'
        $choice = [string](Read-Host 'Language / Ngon ngu')
        switch ($choice.Trim().ToLowerInvariant()) {
            { $_ -in @('1', 'en', 'english') } { return 'en' }
            { $_ -in @('2', 'vi', 'vietnamese') } { return 'vi' }
            { $_ -in @('0', 'q') } { return $null }
            default { Write-Host 'Invalid choice / Lua chon khong hop le.' -ForegroundColor Yellow }
        }
    }
}

if (-not $Language) { $Language = Read-UiLanguage }
if (-not $Language) { return }

& (Join-Path $PSScriptRoot 'GpuTool.i18n.ps1') -Language $Language
