param(
    [ValidateSet("dynamic-island", "companion")]
    [string]$Flavor = "dynamic-island",
    [ValidateSet("win-x64", "win-arm64")]
    [string]$Runtime = "win-x64",
    [string]$Version = "0.1.4-win.1"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $PSScriptRoot "CharacterEfficiencyIsland.Windows/CharacterEfficiencyIsland.Windows.csproj"
$flavorFile = Join-Path $PSScriptRoot "CharacterEfficiencyIsland.Windows/BuildFlavor.cs"
$distRoot = Join-Path $root "dist/windows"
$publishDir = Join-Path $distRoot "$Flavor/$Runtime"
$expectedFlavor = Get-Content $flavorFile -Raw

if (-not $expectedFlavor.Contains("`"$Flavor`"")) {
    throw "BuildFlavor.cs does not select '$Flavor'. Switch to the matching Git branch before packaging."
}

if (Test-Path $publishDir) {
    Remove-Item $publishDir -Recurse -Force
}
New-Item -ItemType Directory -Path $publishDir -Force | Out-Null

dotnet restore $project -r $Runtime
dotnet publish $project `
    -c Release `
    -r $Runtime `
    --self-contained true `
    --no-restore `
    -o $publishDir `
    -p:Version=$Version `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:DebugType=None `
    -p:DebugSymbols=false

$exe = Join-Path $publishDir "CharacterEfficiencyIsland.exe"
if (-not (Test-Path $exe)) {
    throw "Windows executable was not produced: $exe"
}

$label = if ($Flavor -eq "companion") { "桌宠" } else { "灵动岛" }
$standaloneExe = Join-Path $distRoot "角色效率岛-Windows-$label-$Runtime.exe"
$zip = Join-Path $distRoot "角色效率岛-Windows-$label-$Runtime.zip"
Copy-Item $exe $standaloneExe -Force
if (Test-Path $zip) {
    Remove-Item $zip -Force
}
Compress-Archive -Path (Join-Path $publishDir "*") -DestinationPath $zip -CompressionLevel Optimal

Write-Host "EXE: $standaloneExe"
Write-Host "ZIP: $zip"
