param(
    [ValidateSet("dynamic-island", "companion")]
    [string]$Flavor = "dynamic-island",
    [ValidateSet("win-x64", "win-arm64")]
    [string]$Runtime = "win-x64",
    [ValidateSet("generic", "huang-shaotian", "zhang-xinjie", "ye-xiu", "ye-xiu-a", "su-mucheng", "su-muqiu", "yu-wenzhou")]
    [string]$CharacterPack = "generic",
    [string]$Version = "0.1.4-win.4"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $PSScriptRoot "CharacterEfficiencyIsland.Windows/CharacterEfficiencyIsland.Windows.csproj"
$projectDirectory = Split-Path -Parent $project
$projectObj = Join-Path $projectDirectory "obj"
$projectBin = Join-Path $projectDirectory "bin"
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

function New-WindowsAppIcon {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    Add-Type -AssemblyName System.Drawing.Common
    $sourceImage = [System.Drawing.Image]::FromFile($Source)
    $iconSizes = @(16, 20, 24, 32, 40, 48, 64, 128, 256)
    $pngStreams = [System.Collections.Generic.List[System.IO.MemoryStream]]::new()
    try {
        foreach ($iconSize in $iconSizes) {
            $canvas = [System.Drawing.Bitmap]::new(
                $iconSize,
                $iconSize,
                [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $graphics = [System.Drawing.Graphics]::FromImage($canvas)
            try {
                $graphics.Clear([System.Drawing.Color]::Transparent)
                $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

                $inset = [Math]::Max(1, [int][Math]::Round($iconSize / 64.0))
                $available = $iconSize - ($inset * 2)
                $scale = [Math]::Min($available / $sourceImage.Width, $available / $sourceImage.Height)
                $width = [Math]::Max(1, [int][Math]::Round($sourceImage.Width * $scale))
                $height = [Math]::Max(1, [int][Math]::Round($sourceImage.Height * $scale))
                $left = [int](($iconSize - $width) / 2)
                $top = [int](($iconSize - $height) / 2)
                $graphics.DrawImage($sourceImage, $left, $top, $width, $height)

                $pngStream = [System.IO.MemoryStream]::new()
                $canvas.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
                $pngStream.Position = 0
                $pngStreams.Add($pngStream)
            }
            finally {
                $graphics.Dispose()
                $canvas.Dispose()
            }
        }

        $destinationFolder = Split-Path -Parent $Destination
        New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
        $stream = [System.IO.File]::Create($Destination)
        $writer = [System.IO.BinaryWriter]::new($stream)
        try {
            # ICONDIR: reserved, image type, image count.
            $writer.Write([uint16]0)
            $writer.Write([uint16]1)
            $writer.Write([uint16]$iconSizes.Count)

            $dataOffset = 6 + (16 * $iconSizes.Count)
            for ($index = 0; $index -lt $iconSizes.Count; $index++) {
                $iconSize = $iconSizes[$index]
                $pngLength = [uint32]$pngStreams[$index].Length
                $dimension = if ($iconSize -eq 256) { [byte]0 } else { [byte]$iconSize }
                $writer.Write($dimension)
                $writer.Write($dimension)
                $writer.Write([byte]0)
                $writer.Write([byte]0)
                $writer.Write([uint16]1)
                $writer.Write([uint16]32)
                $writer.Write($pngLength)
                $writer.Write([uint32]$dataOffset)
                $dataOffset += $pngLength
            }

            foreach ($pngStream in $pngStreams) {
                $pngStream.WriteTo($stream)
            }
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        foreach ($pngStream in $pngStreams) { $pngStream.Dispose() }
        $sourceImage.Dispose()
    }
}

foreach ($generatedDirectory in @($projectObj, $projectBin)) {
    $resolvedProject = [IO.Path]::GetFullPath($projectDirectory) + [IO.Path]::DirectorySeparatorChar
    $resolvedGenerated = [IO.Path]::GetFullPath($generatedDirectory)
    if (-not $resolvedGenerated.StartsWith($resolvedProject, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean build directory outside the Windows project: $resolvedGenerated"
    }
    if (Test-Path -LiteralPath $resolvedGenerated) {
        Remove-Item -LiteralPath $resolvedGenerated -Recurse -Force
    }
}
if (Test-Path $publishDir) {
    Remove-Item $publishDir -Recurse -Force
}
New-Item -ItemType Directory -Path $publishDir -Force | Out-Null
$generatedIcon = Join-Path $projectObj "generated-app-icons/$CharacterPack.ico"
New-WindowsAppIcon -Source (Join-Path $assetRoot "statusIcon.png") -Destination $generatedIcon

dotnet restore $project -r $Runtime -p:CharacterPack=$CharacterPack
if ($LASTEXITCODE -ne 0) {
    throw "dotnet restore failed for character pack '$CharacterPack'."
}
dotnet publish $project `
    -c Release `
    -r $Runtime `
    --self-contained true `
    --no-restore `
    -o $publishDir `
    -p:Version=$Version `
    -p:CharacterPack=$CharacterPack `
    -p:ApplicationIcon=$generatedIcon `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:DebugType=None `
    -p:DebugSymbols=false
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed for character pack '$CharacterPack'."
}

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
