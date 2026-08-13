[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackagePath,
    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$PackagePath = [IO.Path]::GetFullPath($PackagePath)
$dependencies = Join-Path $repo 'dist\mods\2.3.1.2'
$settingsApi = Join-Path $dependencies 'aslain.modssettingsapi_1.7.1.wotmod'
$gameface = Join-Path $dependencies 'net.openwg\net.openwg.gameface_1.1.6.wotmod'
$releaseRoot = Join-Path $repo ('build\release-{0}-full' -f $Version)
$modsRoot = Join-Path $releaseRoot 'mods\2.3.1.2'
$outputPath = Join-Path $repo ('dist\hangar_carousel_classic_{0}_full.zip' -f $Version)

foreach ($source in @($PackagePath, $settingsApi, $gameface)) {
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Fullpack dependency is missing: $source"
    }
}

Remove-Item -LiteralPath $releaseRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path (Join-Path $modsRoot 'net.openwg') | Out-Null
Copy-Item -LiteralPath $PackagePath -Destination (Join-Path $modsRoot ([IO.Path]::GetFileName($PackagePath)))
Copy-Item -LiteralPath $settingsApi -Destination (Join-Path $modsRoot ([IO.Path]::GetFileName($settingsApi)))
Copy-Item -LiteralPath $gameface -Destination (Join-Path $modsRoot 'net.openwg\net.openwg.gameface_1.1.6.wotmod')

Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($releaseRoot, $outputPath, [IO.Compression.CompressionLevel]::NoCompression, $false)

$archive = [IO.Compression.ZipFile]::OpenRead($outputPath)
try {
    $required = @(
        ('mods/2.3.1.2/' + [IO.Path]::GetFileName($PackagePath)),
        'mods/2.3.1.2/aslain.modssettingsapi_1.7.1.wotmod',
        'mods/2.3.1.2/net.openwg/net.openwg.gameface_1.1.6.wotmod'
    )
    $entries = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    foreach ($entry in $required) {
        if ($entry -notin $entries) {
            throw "Fullpack entry is missing: $entry"
        }
    }
}
finally {
    $archive.Dispose()
}

Write-Output "Built full package: $outputPath"