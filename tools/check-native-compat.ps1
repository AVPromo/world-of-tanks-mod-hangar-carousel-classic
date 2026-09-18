[CmdletBinding()]
param(
    [string]$GameRoot = '',
    # Path to the mod repo whose tools\patch-native-*.ps1 scripts should be
    # checked. Defaults to this script's own repo (mini_rework), so existing
    # calls keep working unchanged. Pass e.g. the Extended repo root to check
    # that mod's patch scripts instead - no duplication of this tool needed.
    [string]$RepoRoot = ''
)

# Diagnostic-only tool: checks whether the native WoT bundles referenced by
# a mod's patch-native-carousel.ps1 / patch-native-tooltip.ps1 still match a
# known, supported hash, and whether every hardcoded patch pattern still
# occurs exactly once in the current bundle source. It NEVER writes to the
# hash lists or the bundles themselves - any required changes must be
# reviewed and applied by hand in the patch scripts.
#
# Usage:
#   .\check-native-compat.ps1                                   # checks this repo (mini_rework)
#   .\check-native-compat.ps1 -GameRoot 'G:\Games\WoT'           # explicit client root
#   .\check-native-compat.ps1 -RepoRoot 'E:\...\mod_hangar_carousel_classic'  # checks Extended instead

$ErrorActionPreference = 'Stop'
$repo = if ($RepoRoot) { [IO.Path]::GetFullPath($RepoRoot) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')) }
$toolsDir = Join-Path $repo 'tools'
$carouselScriptPath = Join-Path $toolsDir 'patch-native-carousel.ps1'
$tooltipScriptPath = Join-Path $toolsDir 'patch-native-tooltip.ps1'

if (-not (Test-Path -LiteralPath $carouselScriptPath)) {
    throw "patch-native-carousel.ps1 not found under $toolsDir - is -RepoRoot pointing at a mod repo with the same tools layout?"
}
if (-not (Test-Path -LiteralPath $tooltipScriptPath)) {
    throw "patch-native-tooltip.ps1 not found under $toolsDir - is -RepoRoot pointing at a mod repo with the same tools layout?"
}

Write-Output "Checked repo: $repo"

function Resolve-GameRoot {
    param([string]$PreferredRoot)

    $candidates = @()
    if ($PreferredRoot) {
        $candidates += $PreferredRoot
    }
    if ($env:WOT_ROOT) {
        $candidates += $env:WOT_ROOT
    }
    $candidates += 'G:\Games\World_of_Tanks_EU'
    $candidates += 'E:\Games\World_of_Tanks_EU'

    foreach ($candidate in ($candidates | Where-Object { $_ } | Select-Object -Unique)) {
        try {
            $root = [IO.Path]::GetFullPath($candidate)
        }
        catch {
            continue
        }
        if (Test-Path -LiteralPath (Join-Path $root 'res\packages\gui-part3.pkg')) {
            return $root
        }
    }

    throw "World of Tanks root not found. Set -GameRoot or WOT_ROOT to a valid client root containing res\packages\gui-part3.pkg."
}

function Get-ScriptVariableValues {
    <#
        Extracts one or more top-level "$name = <expression>" assignments from
        a PowerShell script by AST, without executing the rest of the script
        (which may have mandatory parameters or throw on unsupported hashes).
        Returns the materialized value(s) of the requested variable name.
    #>
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$VariableName
    )

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) {
        throw "Failed to parse ${Path}: $($errors[0].Message)"
    }

    $assignments = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
        $node.Left.VariablePath.UserPath -eq $VariableName
    }, $true)

    if (-not $assignments -or $assignments.Count -eq 0) {
        throw "Variable `$$VariableName was not found in $Path"
    }

    # Only the assignment expression itself is evaluated, in an isolated
    # scope, so nothing else in the source file runs.
    $expressionText = $assignments[0].Right.Extent.Text
    return Invoke-Expression $expressionText
}

function Read-PackageEntryBytes {
    param(
        [Parameter(Mandatory = $true)] [string]$PackagePath,
        [Parameter(Mandatory = $true)] [string]$EntryPath
    )

    $zip = [IO.Compression.ZipFile]::OpenRead($PackagePath)
    try {
        $entry = $zip.GetEntry($EntryPath)
        if (-not $entry) {
            throw "Entry missing in $PackagePath : $EntryPath"
        }
        $stream = $entry.Open()
        $memory = New-Object IO.MemoryStream
        try {
            $stream.CopyTo($memory)
            return $memory.ToArray()
        }
        finally {
            $memory.Dispose()
            $stream.Dispose()
        }
    }
    finally {
        $zip.Dispose()
    }
}

function Get-BytesHash {
    param([byte[]]$Bytes)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return (($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString('X2') }) -join '')
    }
    finally {
        $sha.Dispose()
    }
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$GameRoot = Resolve-GameRoot -PreferredRoot $GameRoot
Write-Output "Game root: $GameRoot"
Write-Output ''

$overallOk = $true

# --- Carousel bundle -------------------------------------------------------
Write-Output '== Native carousel bundle (gui-part3.pkg) =='
$carouselSupportedHashes = Get-ScriptVariableValues -Path $carouselScriptPath -VariableName 'supportedHashes'
$carouselReplacements = Get-ScriptVariableValues -Path $carouselScriptPath -VariableName 'replacements'

$carouselBytes = Read-PackageEntryBytes `
    -PackagePath (Join-Path $GameRoot 'res\packages\gui-part3.pkg') `
    -EntryPath 'gui/gameface/_dist/production/mono/hangar/views/main/main.html/bundle.js'
$carouselHash = Get-BytesHash $carouselBytes
$carouselHashKnown = $carouselHash -in $carouselSupportedHashes
Write-Output "Hash: $carouselHash"
if ($carouselHashKnown) {
    Write-Output 'Hash status: KNOWN (matches an existing supported hash entry)'
}
else {
    $overallOk = $false
    Write-Output 'Hash status: UNKNOWN (client bundle changed - patterns below still checked for reference)'
}
Write-Output ''

$carouselSource = [Text.Encoding]::UTF8.GetString($carouselBytes)
$patternIndex = 0
foreach ($replacement in $carouselReplacements) {
    $patternIndex++
    $from = $replacement[0]
    $count = ([regex]::Matches($carouselSource, [regex]::Escape($from))).Count
    $status = switch ($count) {
        1 { 'OK' }
        0 { 'MISSING'; $overallOk = $false }
        default { 'AMBIGUOUS'; $overallOk = $false }
    }
    $preview = if ($from.Length -gt 70) { $from.Substring(0, 70) + '...' } else { $from }
    Write-Output ("[{0}] pattern #{1,2}: {2} matches - {3}" -f $status, $patternIndex, $count, $preview)
}
Write-Output ''

# --- Tooltip bundle + css ---------------------------------------------------
Write-Output '== Native tooltip bundle (gui-part4.pkg) / stylesheet (gui-part2.pkg) =='
$tooltipSupportedBundleHashes = Get-ScriptVariableValues -Path $tooltipScriptPath -VariableName 'supportedBundleHashes'
$tooltipSupportedCssHashes = Get-ScriptVariableValues -Path $tooltipScriptPath -VariableName 'supportedCssHashes'

$tooltipBundleBytes = Read-PackageEntryBytes `
    -PackagePath (Join-Path $GameRoot 'res\packages\gui-part4.pkg') `
    -EntryPath 'gui/gameface/_dist/production/mono/hangar/views/vehicle_tooltip/vehicle_tooltip.html/bundle.js'
$tooltipCssBytes = Read-PackageEntryBytes `
    -PackagePath (Join-Path $GameRoot 'res\packages\gui-part2.pkg') `
    -EntryPath 'gui/gameface/_dist/production/mono/hangar/vehicle_tooltip/vehicle_tooltip.css'

$tooltipBundleHash = Get-BytesHash $tooltipBundleBytes
$tooltipCssHash = Get-BytesHash $tooltipCssBytes
$tooltipBundleKnown = $tooltipBundleHash -in $tooltipSupportedBundleHashes
$tooltipCssKnown = $tooltipCssHash -in $tooltipSupportedCssHashes

Write-Output "Bundle hash: $tooltipBundleHash -> $(if ($tooltipBundleKnown) { 'KNOWN' } else { 'UNKNOWN' })"
Write-Output "CSS hash:    $tooltipCssHash -> $(if ($tooltipCssKnown) { 'KNOWN' } else { 'UNKNOWN' })"
if (-not $tooltipBundleKnown -or -not $tooltipCssKnown) {
    $overallOk = $false
    Write-Output 'Note: the tooltip patch only appends the mod renderer; no string patterns to verify, but the hash gate in patch-native-tooltip.ps1 must be extended with the new hash(es) after a manual review confirms nothing else changed structurally.'
}
Write-Output ''

# --- Summary -----------------------------------------------------------------
if ($overallOk) {
    Write-Output 'RESULT: All hashes and patch patterns are consistent with the current game client. No action needed.'
    exit 0
}
else {
    Write-Output 'RESULT: Action needed before building against this client version.'
    Write-Output ' - For UNKNOWN hashes: manually review the new bundle, then add the new hash to the relevant $supportedHashes/$supportedBundleHashes/$supportedCssHashes list.'
    Write-Output ' - For MISSING/AMBIGUOUS patterns: the client bundle text changed around that patch point; update the corresponding "from"/"to" pair in patch-native-carousel.ps1 by hand.'
    exit 1
}
