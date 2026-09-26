[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GameRoot,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$GameRoot = [IO.Path]::GetFullPath($GameRoot)
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$packagePath = Join-Path $GameRoot 'res\packages\comp7.pkg'
$entryPath = 'comp7/gui/gameface/_dist/production/mono/lobby/views/hangar/hangar.html/bundle.js'
$supportedHashes = @(
    '2067FD7C155BC180E12DAF1825DB5E1BCAEBFA094D660E167D33B2FB24FEB6DA' # WoT 2.4.0.1
)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($packagePath)
try {
    $entry = $zip.GetEntry($entryPath)
    if (-not $entry) {
        throw "Comp7 hangar bundle is missing: $entryPath"
    }
    $stream = $entry.Open()
    $memory = New-Object IO.MemoryStream
    try {
        $stream.CopyTo($memory)
        $sourceBytes = $memory.ToArray()
    }
    finally {
        $memory.Dispose()
        $stream.Dispose()
    }
}
finally {
    $zip.Dispose()
}

$sha = [Security.Cryptography.SHA256]::Create()
try {
    $sourceHash = (($sha.ComputeHash($sourceBytes) | ForEach-Object { $_.ToString('X2') }) -join '')
}
finally {
    $sha.Dispose()
}
if ($sourceHash -notin $supportedHashes) {
    throw "Unsupported Comp7 hangar bundle $sourceHash; supported hashes: $($supportedHashes -join ', ')"
}

$source = [Text.Encoding]::UTF8.GetString($sourceBytes)
$replacements = @(
    @(
        '2===e?t.double:t.single',
        '1<e?t.double:t.single'
    ),
    @(
        '2!==t?{visibleSlots:Math.ceil(s/a),cardWidth:a,carouselRows:t}:{visibleSlots:Math.ceil(s/a*t),cardWidth:a,carouselRows:t}',
        '1===t?{visibleSlots:Math.ceil(s/a),cardWidth:a,carouselRows:t}:{visibleSlots:Math.ceil(s/a*t),cardWidth:a,carouselRows:t}'
    ),
    @(
        'w=(N=C,m.useMemo(()=>{const e=[];for(let t=0;t<N.length;t+=2)e.push(N.slice(t,t+2));return 1===e.at(-1)?.length&&e.at(-1)?.push(nf),e},[N]));var N;',
        'w=(N=C,m.useMemo(()=>{const e=[];for(let t=0;t<N.length;t+=b)e.push(N.slice(t,t+b));const a=e.at(-1);if(a)for(;a.length<b;)a.push(nf);return e},[N,b]));var N;'
    ),
    @(
        'function(e,t,a,s,n){const r=2===s;function i(s)',
        'function(e,t,a,s,n){const r=1<s;function i(s)'
    ),
    @(
        'totalElements:2===b?w.length:C.length',
        'totalElements:1<b?w.length:C.length'
    ),
    @(
        'return 2===b?',
        'return 1<b?'
    ),
    @(
        'className:g(qU,2===s&&$U)',
        'className:g(qU,1<s&&$U,3===s&&"hcc-native-carousel-page--3",4===s&&"hcc-native-carousel-page--4")'
    )
)

foreach ($replacement in $replacements) {
    $from = $replacement[0]
    $to = $replacement[1]
    $count = ([regex]::Matches($source, [regex]::Escape($from))).Count
    if ($count -ne 1) {
        throw "Expected one Comp7 carousel patch point, found $count for: $from"
    }
    $source = $source.Replace($from, $to)
}

$directory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $directory | Out-Null
[IO.File]::WriteAllText($OutputPath, $source, (New-Object Text.UTF8Encoding($false)))
Write-Output "Patched Comp7 hangar bundle: $OutputPath"
