[CmdletBinding()]
param(
    [string]$Root = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $PSScriptRoot }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Read-ParsedFile([string]$Path) {
    Assert-True (Test-Path -LiteralPath $Path) "Missing required file: $Path"
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw "$Path does not parse: $(($errors | ForEach-Object Message) -join '; ')" }
    return @{ Ast = $ast; Tokens = $tokens; Text = [System.IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) }
}

function Get-FunctionText($Ast, [string]$Name) {
    $node = $Ast.Find({ param($item) $item -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $item.Name -eq $Name }, $true)
    Assert-True ($null -ne $node) "Function '$Name' was not found"
    return $node.Extent.Text
}

function Get-FormatTokens([string]$Text) {
    return @([regex]::Matches($Text, '\{\d+(?:,-?\d+)?(?::[^}]+)?\}') | ForEach-Object Value | Sort-Object)
}

$runtimePath = Join-Path $Root 'GpuTool.i18n.ps1'
$selectorPath = Join-Path $Root 'Start-GpuTool.ps1'
$enPath = Join-Path $Root 'locales\en.json'
$viPath = Join-Path $Root 'locales\vi.json'

$runtime = Read-ParsedFile $runtimePath
$selector = Read-ParsedFile $selectorPath

foreach ($localePath in @($enPath, $viPath)) {
    Assert-True (Test-Path -LiteralPath $localePath) "Missing locale: $localePath"
    $localeText = [System.IO.File]::ReadAllText($localePath, [Text.Encoding]::UTF8)
    Assert-True ($localeText -notmatch '[^\x00-\x7F]') "Locale must be ASCII: $localePath"
}
$en = Get-Content -LiteralPath $enPath -Raw -Encoding UTF8 | ConvertFrom-Json
$vi = Get-Content -LiteralPath $viPath -Raw -Encoding UTF8 | ConvertFrom-Json
$enKeys = @($en.PSObject.Properties.Name | Sort-Object)
$viKeys = @($vi.PSObject.Properties.Name | Sort-Object)
# The supplied Vietnamese file retains unused legacy keys. Validate the
# supported English keys and every referenced runtime key without removing them.
foreach ($key in $enKeys) {
    Assert-True ($null -ne $vi.PSObject.Properties[$key]) "Vietnamese locale key missing: $key"
}
foreach ($key in $enKeys) {
    $enFormats = (Get-FormatTokens ([string]$en.$key)) -join '|'
    $viFormats = (Get-FormatTokens ([string]$vi.$key)) -join '|'
    Assert-True ($enFormats -eq $viFormats) "Format placeholders differ for $key"
}

Assert-True ($runtime.Text -match "\[ValidateSet\(\s*'en'\s*,\s*'vi'\s*\)\]") 'Runtime must validate en/vi language'
Assert-True ($runtime.Text -match 'function\s+Get-UiText') 'Runtime must provide Get-UiText'
Assert-True ($selector.Text -match 'function\s+Read-UiLanguage') 'Selector must provide Read-UiLanguage'
Assert-True ($selector.Text -match 'GpuTool\.i18n\.ps1') 'Selector must invoke bilingual runtime'
Assert-True ($runtime.Text -match 'Start-Process\s+powershell\.exe') 'Runtime must retain its UAC elevation flow'
$elevationCommand = $runtime.Ast.Find({ param($item) $item -is [System.Management.Automation.Language.CommandAst] -and $item.GetCommandName() -eq 'Start-Process' }, $true)
Assert-True ($null -ne $elevationCommand -and $elevationCommand.Extent.Text -match "'-Language'\s*,\s*\`$Language") 'Runtime elevation must forward the selected language'
Assert-True ($selector.Ast.EndBlock.Statements[-1].Extent.Text -match '-Language\s+\$Language') 'Selector must forward the selected language to the runtime'
Assert-True ($en.K0190 -ceq 'GpuTool' -and $vi.K0190 -ceq 'GpuTool') 'Both locales must preserve the ICC settings identity'

$forbidden = @(
    '\bGet-MachineId\b', '\bGet-Lic\w*\b', '\bInvoke-LicenseGate\b', '\bInvoke-Activate\b',
    '\bInvoke-AutoRevert\b', '\bAutoReverted\b', '\blicense\.dat\b', '\bused\.dat\b',
    '\bWin32_BaseBoard\b', '\bWin32_Processor\b', '\bWin32_BIOS\b', '\bWin32_LogicalDisk\b',
    '(?i)\b(?:VX|QQ)\s*:'
)
foreach ($pattern in $forbidden) {
    Assert-True ($runtime.Text -notmatch $pattern) "Removed activation, fingerprint, expiry, or credit content remains: $pattern"
}

$referencedKeys = @([regex]::Matches($runtime.Text, 'Get-UiText\s+\(?\s*[\x27\"]?(K\d{4})') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-True ($referencedKeys.Count -gt 0) 'Runtime does not reference localized UI keys'
foreach ($key in $referencedKeys) {
    Assert-True ($null -ne $en.$key -and $null -ne $vi.$key) "Referenced locale key is missing: $key"
}

$aceSelfTest = Get-FunctionText $runtime.Ast 'Invoke-AceSelfTest'
$aceWatchdog = Get-FunctionText $runtime.Ast 'Start-AceWatchdog'
Assert-True ($aceSelfTest -match '\[ProcThrottle\]::SetEco\(\$p\.Id, \$true\)') 'ACE self-test must enable EcoQoS'
Assert-True ($aceSelfTest -match '\[ProcThrottle\]::SetEco\(\$p\.Id, \$false\)') 'ACE self-test must restore EcoQoS'
Assert-True ($aceSelfTest -match 'Start-AceWatchdog\s+-IntervalSec\s+14') 'ACE self-test must offer the 14-second watchdog'
Assert-True ($aceWatchdog -match '\[ProcThrottle\]::SetEco\(\$p\.Id, \$true\)') 'ACE watchdog must repair EcoQoS'

# The following executes only extracted menu/selector code. All hardware handlers are mocks.
$getUiText = Get-FunctionText $runtime.Ast 'Get-UiText'
$menuStart = $runtime.Text.IndexOf('$exit = $false')
Assert-True ($menuStart -ge 0) 'Runtime main menu loop not found'
$mainLoop = $runtime.Text.Substring($menuStart)
foreach ($language in @('en', 'vi')) {
    Remove-Variable UiStrings -Scope Script -ErrorAction SilentlyContinue
    $script:UiStrings = if ($language -eq 'en') { $en } else { $vi }
    . ([scriptblock]::Create($getUiText))
    $script:menuInputs = [Collections.Queue]::new()
    @('1','2','3','4','5','6','7','8','0') | ForEach-Object { $script:menuInputs.Enqueue($_) }
    $script:menuCalls = @{}
    $script:menuOutput = @()
    function Read-Host { param([string]$Prompt) if ($script:menuInputs.Count -eq 0) { throw 'Mock input exhausted' }; [string]$script:menuInputs.Dequeue() }
    function Write-Host { $script:menuOutput += (($args | ForEach-Object { [string]$_ }) -join ' ') }
    function Show-Current { $script:menuCalls['1']++ }
    function Invoke-Spoof { $script:menuCalls['2']++ }
    function Invoke-Restore { $script:menuCalls['3']++ }
    function Show-IccMenu { $script:menuCalls['4']++ }
    function Invoke-IccRestore { $script:menuCalls['5']++ }
    function Invoke-AceSelfTest { $script:menuCalls['6']++ }
    $SpoofName = 'mock GPU'
    & ([scriptblock]::Create($mainLoop))
    foreach ($choice in '1','2','3','4','5','6') { Assert-True ($script:menuCalls[$choice] -eq 1) "$language menu choice $choice did not dispatch once" }
    Assert-True (@($script:menuOutput | Where-Object { $_ -match 'invalid|khong hop le' }).Count -eq 2) "$language choices 7/8 were not rejected"
    Set-Variable -Name ("menuOutput_$language") -Value $script:menuOutput -Scope Script
}
Assert-True ((($script:menuOutput_en -join "`n") -ne ($script:menuOutput_vi -join "`n"))) 'English and Vietnamese menu output must differ'

$readLanguage = Get-FunctionText $selector.Ast 'Read-UiLanguage'
function Invoke-SelectorTest([string[]]$Inputs) {
    $script:selectorInputs = [Collections.Queue]::new()
    $Inputs | ForEach-Object { $script:selectorInputs.Enqueue($_) }
    function Read-Host { param([string]$Prompt) if ($script:selectorInputs.Count -eq 0) { throw 'Selector mock input exhausted' }; [string]$script:selectorInputs.Dequeue() }
    function Write-Host { }
    . ([scriptblock]::Create($readLanguage))
    return Read-UiLanguage
}
Assert-True ((Invoke-SelectorTest @('1')) -eq 'en') 'Selector 1 must choose English'
Assert-True ((Invoke-SelectorTest @('ENGLISH')) -eq 'en') 'Selector must accept English case-insensitively'
Assert-True ((Invoke-SelectorTest @('2')) -eq 'vi') 'Selector 2 must choose Vietnamese'
Assert-True ((Invoke-SelectorTest @('Vietnamese')) -eq 'vi') 'Selector must accept Vietnamese name'
Assert-True ((Invoke-SelectorTest @('x','vi')) -eq 'vi') 'Selector must retry after invalid input'
Assert-True ((Invoke-SelectorTest @('','en')) -eq 'en') 'Selector must retry after blank input'
Assert-True ($null -eq (Invoke-SelectorTest @('q'))) 'Selector q must exit'

[pscustomobject]@{
    RuntimeParsed = $true
    SelectorParsed = $true
    LocaleKeys = $enKeys.Count
    LocalesAscii = $true
    ActivationAndFingerprintRemoved = $true
    MenuMocked = $true
    SelectorMocked = $true
    TargetExecuted = $false
    Result = 'PASS'
} | ConvertTo-Json
