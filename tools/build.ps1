[CmdletBinding()]
param(
    [string]$Python27,
    [switch]$Install,
    [string]$GameRoot = ''
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$build = Join-Path $repo 'build'
$stage = Join-Path $build 'stage'
$dist = Join-Path $repo 'dist'
$version = '1.0.2'
$packageName = "mod_hangar_carousel_classic_$version.wotmod"
$packagePath = Join-Path $dist $packageName

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

    throw "World of Tanks root not found. Set -GameRoot or WOT_ROOT to a valid client root containing res\\packages\\gui-part3.pkg."
}

$GameRoot = Resolve-GameRoot -PreferredRoot $GameRoot

if (-not $Python27) {
    $Python27 = & (Join-Path $PSScriptRoot 'bootstrap-python27.ps1')
}
$Python27 = [IO.Path]::GetFullPath(($Python27 | Select-Object -Last 1))
if (-not (Test-Path -LiteralPath $Python27)) {
    throw "Python 2.7 not found: $Python27"
}

Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path `
    (Join-Path $stage 'res\scripts\client\gui\mods'), `
    (Join-Path $stage 'res\gui\gameface\mods\hcc\hangar_carousel_classic'), `
    (Join-Path $stage 'res\gui\gameface\_dist\production\mono\hangar\views\main\main.html'), `
    (Join-Path $stage 'res\gui\gameface\_dist\production\mono\hangar\views\vehicle_tooltip\vehicle_tooltip.html'), `
    (Join-Path $stage 'res\gui\gameface\_dist\production\mono\hangar\vehicle_tooltip'), `
    $dist | Out-Null

$pythonSource = Join-Path $repo 'res\scripts\client\gui\mods\mod_hangar_carousel_classic.py'
$pythonText = Get-Content -LiteralPath $pythonSource -Raw
if ($pythonText.Contains('.createPlaylist(')) {
    throw 'Classic must not create dynamic vehicle playlists.'
}
& $Python27 -m py_compile $pythonSource
if ($LASTEXITCODE -ne 0) {
    throw 'Python 2.7 compilation failed.'
}
$compiled = "$pythonSource`c"

Copy-Item -LiteralPath (Join-Path $repo 'meta.xml') -Destination (Join-Path $stage 'meta.xml')
Copy-Item -LiteralPath $compiled -Destination (Join-Path $stage 'res\scripts\client\gui\mods\mod_hangar_carousel_classic.pyc')
Copy-Item -LiteralPath (Join-Path $repo 'res\gui\gameface\mods\hcc\hangar_carousel_classic\hangar_carousel_classic.js') `
    -Destination (Join-Path $stage 'res\gui\gameface\mods\hcc\hangar_carousel_classic\hangar_carousel_classic.js')
Copy-Item -LiteralPath (Join-Path $repo 'res\gui\gameface\mods\hcc\hangar_carousel_classic\hangar_carousel_classic.tooltip.js') `
    -Destination (Join-Path $stage 'res\gui\gameface\mods\hcc\hangar_carousel_classic\hangar_carousel_classic.tooltip.js')
Copy-Item -LiteralPath (Join-Path $repo 'res\gui\gameface\mods\hcc\hangar_carousel_classic\hangar_carousel_classic.css') `
    -Destination (Join-Path $stage 'res\gui\gameface\mods\hcc\hangar_carousel_classic\hangar_carousel_classic.css')
Copy-Item -LiteralPath (Join-Path $repo 'res\gui\gameface\mods\hcc\hangar_carousel_classic\hangar_carousel_classic.tooltip.css') `
    -Destination (Join-Path $stage 'res\gui\gameface\mods\hcc\hangar_carousel_classic\hangar_carousel_classic.tooltip.css')
& (Join-Path $PSScriptRoot 'patch-native-carousel.ps1') `
    -GameRoot $GameRoot `
    -OutputPath (Join-Path $stage 'res\gui\gameface\_dist\production\mono\hangar\views\main\main.html\bundle.js')
& (Join-Path $PSScriptRoot 'patch-native-tooltip.ps1') `
    -GameRoot $GameRoot `
    -BundleOutputPath (Join-Path $stage 'res\gui\gameface\_dist\production\mono\hangar\views\vehicle_tooltip\vehicle_tooltip.html\bundle.js') `
    -CssOutputPath (Join-Path $stage 'res\gui\gameface\_dist\production\mono\hangar\vehicle_tooltip\vehicle_tooltip.css') `
    -ScriptPath (Join-Path $repo 'res\gui\gameface\mods\hcc\hangar_carousel_classic\hangar_carousel_classic.tooltip.js') `
    -StylePath (Join-Path $repo 'res\gui\gameface\mods\hcc\hangar_carousel_classic\hangar_carousel_classic.tooltip.css')

Remove-Item -LiteralPath $packagePath -Force -ErrorAction SilentlyContinue
& $Python27 (Join-Path $PSScriptRoot 'package_wotmod.py') $stage $packagePath
if ($LASTEXITCODE -ne 0) {
    throw 'WoT package creation failed.'
}

& (Join-Path $PSScriptRoot 'validate.ps1') -PackagePath $packagePath
if ($Install) {
    & (Join-Path $PSScriptRoot 'install.ps1') -GameRoot $GameRoot -PackagePath $packagePath
}

Write-Output $packagePath
