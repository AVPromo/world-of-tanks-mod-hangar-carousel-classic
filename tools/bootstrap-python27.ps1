[CmdletBinding()]
param(
    [string]$Destination = (Join-Path $PSScriptRoot '..\.tools\python27')
)

$ErrorActionPreference = 'Stop'
$Destination = [IO.Path]::GetFullPath($Destination)
$python = Get-ChildItem -LiteralPath $Destination -Recurse -Filter python.exe -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
if ($python) {
    Write-Output $python
    exit 0
}

$cache = Join-Path ([IO.Path]::GetDirectoryName($Destination)) 'cache'
New-Item -ItemType Directory -Force -Path $cache | Out-Null
$msi = Join-Path $cache 'python-2.7.18.amd64.msi'
$minimumMsiBytes = 20000000
$expectedSha256 = 'B74A3AFA1E0BF2A6FC566A7B70D15C9BFABBA3756FB077797D16FFFA27800C05'
if ((Test-Path -LiteralPath $msi) -and (
        (Get-Item -LiteralPath $msi).Length -lt $minimumMsiBytes -or
        (Get-FileHash -Algorithm SHA256 -LiteralPath $msi).Hash -ne $expectedSha256)) {
    Remove-Item -LiteralPath $msi -Force
}
if (-not (Test-Path -LiteralPath $msi)) {
    $download = "$msi.download"
    if (-not (Test-Path -LiteralPath $download) -or
        (Get-Item -LiteralPath $download).Length -lt $minimumMsiBytes -or
        (Get-FileHash -Algorithm SHA256 -LiteralPath $download).Hash -ne $expectedSha256) {
        Remove-Item -LiteralPath $download -Force -ErrorAction SilentlyContinue
        Invoke-WebRequest -UseBasicParsing `
            -Uri 'https://www.python.org/ftp/python/2.7.18/python-2.7.18.amd64.msi' `
            -OutFile $download
    }
    if ((Get-Item -LiteralPath $download).Length -lt $minimumMsiBytes) {
        throw 'The Python 2.7 MSI download is incomplete.'
    }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $download).Hash -ne $expectedSha256) {
        throw 'The Python 2.7 MSI checksum does not match the expected official package.'
    }
    Move-Item -LiteralPath $download -Destination $msi
}

New-Item -ItemType Directory -Force -Path $Destination | Out-Null
$arguments = @('/a', ('"{0}"' -f $msi), '/qn', ('TARGETDIR="{0}"' -f $Destination))
$process = Start-Process -FilePath msiexec.exe -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw "Python 2.7 administrative extraction failed with exit code $($process.ExitCode)."
}

$python = Get-ChildItem -LiteralPath $Destination -Recurse -Filter python.exe |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $python) {
    throw "Python 2.7 executable was not found under $Destination."
}
Write-Output $python
