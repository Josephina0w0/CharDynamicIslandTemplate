param(
    [ValidateSet("dynamic-island", "companion")]
    [string]$Flavor = "dynamic-island",
    [ValidateSet("win-x64", "win-arm64")]
    [string]$Runtime = "win-x64"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$distRoot = Join-Path $root "dist/windows"
$label = if ($Flavor -eq "companion") { "桌宠" } else { "灵动岛" }
$exe = Join-Path $distRoot "角色效率岛-Windows-$label-$Runtime.exe"
$zip = Join-Path $distRoot "角色效率岛-Windows-$label-$Runtime.zip"

foreach ($path in @($exe, $zip)) {
    if (-not (Test-Path $path)) {
        throw "Missing package: $path"
    }
    if ((Get-Item $path).Length -lt 1024) {
        throw "Package is unexpectedly small: $path"
    }
}

$header = [System.IO.File]::ReadAllBytes($exe)[0..1]
if ($header[0] -ne 0x4D -or $header[1] -ne 0x5A) {
    throw "Executable does not have a valid PE header: $exe"
}

$temporary = Join-Path ([System.IO.Path]::GetTempPath()) ("character-island-verify-" + [guid]::NewGuid())
try {
    Expand-Archive -Path $zip -DestinationPath $temporary
    $zippedExe = Join-Path $temporary "CharacterEfficiencyIsland.exe"
    if (-not (Test-Path $zippedExe)) {
        throw "ZIP does not contain CharacterEfficiencyIsland.exe"
    }
    $version = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($zippedExe)
    Write-Host "Verified: $zip"
    Write-Host "File version: $($version.FileVersion)"
    Write-Host "Size: $((Get-Item $zip).Length) bytes"
}
finally {
    if (Test-Path $temporary) {
        Remove-Item $temporary -Recurse -Force
    }
}
