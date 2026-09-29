param(
    [ValidateSet("dynamic-island", "companion")]
    [string]$Flavor = "dynamic-island",
    [ValidateSet("win-x64", "win-arm64")]
    [string]$Runtime = "win-x64",
    [ValidateSet("generic", "huang-shaotian", "zhang-xinjie", "ye-xiu", "ye-xiu-a", "su-mucheng", "su-muqiu", "yu-wenzhou")]
    [string]$CharacterPack = "generic",
    [string]$Version = "0.1.4-win.1"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $PSScriptRoot "CharacterEfficiencyIsland.Windows/CharacterEfficiencyIsland.Windows.csproj"
$flavorFile = Join-Path $PSScriptRoot "CharacterEfficiencyIsland.Windows/BuildFlavor.cs"
$profilePath = if ($CharacterPack -eq "generic") {
    Join-Path $PSScriptRoot "CharacterEfficiencyIsland.Windows/profile.json"
} else {
    Join-Path $PSScriptRoot "CharacterPacks/$CharacterPack/profile.json"
}
$assetRoot = if ($CharacterPack -eq "generic") {
    Join-Path $root "Sources/CharacterEfficiencyIsland/Assets"
} else {
    Join-Path $PSScriptRoot "CharacterPacks/$CharacterPack/Assets"
}
$distRoot = Join-Path $root "dist/windows"
$publishDir = Join-Path $distRoot "$Flavor/$CharacterPack/$Runtime"
$expectedFlavor = Get-Content $flavorFile -Raw

if (-not $expectedFlavor.Contains("`"$Flavor`"")) {
    throw "BuildFlavor.cs does not select '$Flavor'. Switch to the matching Git branch before packaging."
}
if (-not (Test-Path $profilePath)) {
    throw "Character profile does not exist: $profilePath"
}
$profile = Get-Content $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
$appName = [string]$profile.appName
if ([string]::IsNullOrWhiteSpace($appName)) {
    throw "Character profile is missing appName: $profilePath"
}
$requiredAssets = @(
    "working", "break", "idle", "alert", "ai", "water",
    "reminder-first", "reminder-second", "reminder-third", "reminder-fourth",
    "panel-working", "panel-break", "panel-idle", "panel-water", "panel-ai",
    "panel-reminder-second", "panel-reminder-third", "panel-reminder-fourth",
    "statusIcon"
)
foreach ($asset in $requiredAssets) {
    $assetPath = Join-Path $assetRoot "$asset.png"
    if (-not (Test-Path $assetPath)) {
        throw "Character pack '$CharacterPack' is missing $assetPath"
    }
}

if (Test-Path $publishDir) {
    Remove-Item $publishDir -Recurse -Force
}
New-Item -ItemType Directory -Path $publishDir -Force | Out-Null

dotnet restore $project -r $Runtime -p:CharacterPack=$CharacterPack
dotnet publish $project `
    -c Release `
    -r $Runtime `
    --self-contained true `
    --no-restore `
    -o $publishDir `
    -p:Version=$Version `
    -p:CharacterPack=$CharacterPack `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:DebugType=None `
    -p:DebugSymbols=false

$exe = Join-Path $publishDir "CharacterEfficiencyIsland.exe"
if (-not (Test-Path $exe)) {
    throw "Windows executable was not produced: $exe"
}

$packagedExeName = if ($CharacterPack -eq "generic") { "CharacterEfficiencyIsland.exe" } else { "$appName.exe" }
$packagedExe = Join-Path $publishDir $packagedExeName
if ($packagedExe -ne $exe) {
    Move-Item $exe $packagedExe -Force
}

$label = if ($Flavor -eq "companion") { "桌宠" } else { "灵动岛" }
$standaloneExe = Join-Path $distRoot "$appName-Windows-$label-$Runtime.exe"
$zip = Join-Path $distRoot "$appName-Windows-$label-$Runtime.zip"
Copy-Item $packagedExe $standaloneExe -Force
if (Test-Path $zip) {
    Remove-Item $zip -Force
}
Compress-Archive -Path (Join-Path $publishDir "*") -DestinationPath $zip -CompressionLevel Optimal

Write-Host "EXE: $standaloneExe"
Write-Host "ZIP: $zip"
