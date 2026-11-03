# Regression tests for QuickAction's GPU selection in Windows PowerShell 5.1.
# Mocked data only: never access Registry or change GPU hardware.
$ErrorActionPreference = 'Stop'
$source = Join-Path (Split-Path $PSScriptRoot -Parent) 'GpuTool.i18n.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $source, [ref]$tokens, [ref]$parseErrors
)
if ($parseErrors.Count -ne 0) {
    throw ('Invalid PowerShell source: ' + ($parseErrors | Out-String))
}
$func = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Invoke-QuickGpuAction'
}, $true)
if (-not $func) { throw 'Invoke-QuickGpuAction was not found' }
Invoke-Expression $func.Extent.Text

$script:mockAdapters = @()
$script:promptCount = 0
function Get-DisplayAdapters {
    foreach ($item in $script:mockAdapters) { $item }
}
function Get-GpuVendorFromId { param([string]$InstanceId) return 'NVIDIA' }
function Read-Host {
    param([string]$Prompt)
    $script:promptCount += 1
    return '0' # Cancel; no real GPU or Registry operations are permitted.
}
function New-MockGpu {
    param([string]$DriverKey)
    return [pscustomobject]@{
        IsReal = $true
        FullInst = 'PCI\VEN_10DE&DEV_1234\' + $DriverKey
        EnumPath = 'HKLM:\MockEnum\' + $DriverKey
        Key = $DriverKey
        GpuKind = 'Discrete'
        Desc = 'NVIDIA GeForce GTX 1050 Ti'
        EnumDesc = 'NVIDIA GeForce GTX 1050 Ti'
    }
}

# Zero GPU: report failure, don't show an empty menu.
$script:mockAdapters = @()
$script:promptCount = 0
$zero = @((Invoke-QuickGpuAction -Action '1050ti' 6>&1) | ForEach-Object { "$_" })
if ($script:promptCount -ne 0) { throw 'Zero GPU case unexpectedly prompted for input' }
if ((@($zero | Where-Object { $_ -match 'Khong tim thay GPU hop le' })).Count -ne 1) {
    throw 'Zero GPU case did not report no available GPU'
}
Write-Host '[PASS] Zero eligible GPUs: no empty selection menu.'

# One GPU: the source's pipeline output must remain an array (Windows PS 5.1).
$script:mockAdapters = @(New-MockGpu -DriverKey '0000')
$script:promptCount = 0
$one = @((Invoke-QuickGpuAction -Action '1050ti' 6>&1) | ForEach-Object { "$_" })
if ($script:promptCount -ne 0) { throw 'Single GPU unexpectedly prompted - scalar .Count regression' }
if ((@($one | Where-Object { $_ -match 'GPU da mang ten' })).Count -ne 1) {
    throw 'Single GPU was not selected automatically'
}
Write-Host '[PASS] Single GPU: automatically selected without prompt.'

# Two GPUs: both numbered choices are visible; cancel without writing.
$script:mockAdapters = @(
    (New-MockGpu -DriverKey '0000'),
    (New-MockGpu -DriverKey '0001')
)
$script:promptCount = 0
$two = @((Invoke-QuickGpuAction -Action '1050ti' 6>&1) | ForEach-Object { "$_" })
if ($script:promptCount -ne 1) { throw 'Two-GPU selection did not prompt exactly once' }
if ((@($two | Where-Object { $_ -match '\[1\]' })).Count -lt 1 -or
    (@($two | Where-Object { $_ -match '\[2\]' })).Count -lt 1) {
    throw 'Two GPU entries were not both printed'
}
Write-Host '[PASS] Two GPUs: both [1] and [2] listed, cancel supported.'
