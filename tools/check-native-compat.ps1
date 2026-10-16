[CmdletBinding()]
param(
    [string]$GameRoot = '',
    # Path to the mod repo whose tools\patch-native-*.ps1 scripts should be
    # checked. Defaults to this script's own repo (mini_rework), so existing
    # calls keep working unchanged. Pass e.g. the Extended repo root to check
    # that mod's patch scripts instead - no duplication of this tool needed.
    [string]$RepoRoot = ''
)

# Diagnostic-only tool: runs the native bundle patchers against the selected
# client, writing only to uniquely named temporary output files.
#
# Usage:
#   .\check-native-compat.ps1                                   # checks this repo (mini_rework)
#   .\check-native-compat.ps1 -GameRoot 'G:\Games\WoT'           # explicit client root
#   .\check-native-compat.ps1 -RepoRoot 'E:\...\mod_hangar_carousel_classic'  # checks Extended instead

$ErrorActionPreference = 'Stop'
$repo = if ($RepoRoot) { [IO.Path]::GetFullPath($RepoRoot) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')) }
$toolsDir = Join-Path $repo 'tools'
$carouselScriptPath = Join-Path $toolsDir 'patch-native-carousel.ps1'
$comp7ScriptPath = Join-Path $toolsDir 'patch-native-comp7-carousel.ps1'
$tooltipScriptPath = Join-Path $toolsDir 'patch-native-tooltip.ps1'

if (-not (Test-Path -LiteralPath $carouselScriptPath)) {
    throw "patch-native-carousel.ps1 not found under $toolsDir - is -RepoRoot pointing at a mod repo with the same tools layout?"
}
if (-not (Test-Path -LiteralPath $tooltipScriptPath)) {
    throw "patch-native-tooltip.ps1 not found under $toolsDir - is -RepoRoot pointing at a mod repo with the same tools layout?"
}
if (-not (Test-Path -LiteralPath $comp7ScriptPath)) {
    throw "patch-native-comp7-carousel.ps1 not found under $toolsDir."
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

$tempBase = Join-Path $env:TEMP ('hcc-native-compat-' + [guid]::NewGuid().ToString('N'))
$mainOutput = $tempBase + '-main.js'
$comp7Output = $tempBase + '-comp7.js'
$tooltipOutput = $tempBase + '-tooltip.js'
$tooltipCssOutput = $tempBase + '-tooltip.css'
$checkFailed = $false

try {
    Write-Output '== Native main carousel =='
    & $carouselScriptPath -GameRoot $GameRoot -OutputPath $mainOutput
    Write-Output '== Comp7 carousel =='
    & $comp7ScriptPath -GameRoot $GameRoot -OutputPath $comp7Output
    Write-Output '== Vehicle tooltip bundle and stylesheet =='
    & $tooltipScriptPath `
        -GameRoot $GameRoot `
        -BundleOutputPath $tooltipOutput `
        -CssOutputPath $tooltipCssOutput `
        -ScriptPath (Join-Path $repo 'res\gui\gameface\mods\hcc\hangar_carousel_classic\hangar_carousel_classic.tooltip.js') `
        -StylePath (Join-Path $repo 'res\gui\gameface\mods\hcc\hangar_carousel_classic\hangar_carousel_classic.tooltip.css')
    Write-Output 'RESULT: Current client hashes and all required patch anchors are supported.'
}
catch {
    Write-Output "RESULT: Current client is not compatible: $($_.Exception.Message)"
    $checkFailed = $true
}
finally {
    foreach ($path in @($mainOutput, $comp7Output, $tooltipOutput, $tooltipCssOutput)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Remove-Item -LiteralPath $path -Force
        }
    }
    if ($checkFailed) {
        exit 1
    }
}
