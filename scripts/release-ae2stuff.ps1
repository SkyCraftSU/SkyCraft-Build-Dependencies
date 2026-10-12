# Build and publish both AE2 Stuff variants from an external project checkout.
# Requires PowerShell 5.1+, GitHub CLI (gh), Git, and working Gradle dependencies.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceProject,
    [string]$Version = '0.5.1.16',
    [string]$Repository = 'denis128873/ae2stuff-0.5.1.16-gtnh',
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $SourceProject).Path
if (-not (Test-Path -LiteralPath (Join-Path $root 'CLIENT\gradlew.bat'))) {
    throw "CLIENT Gradle wrapper not found in $root"
}
if (-not (Test-Path -LiteralPath (Join-Path $root 'SERVER\gradlew.bat'))) {
    throw "SERVER Gradle wrapper not found in $root"
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'Install GitHub CLI (gh) and run gh auth login.'
}
& gh auth status
if ($LASTEXITCODE -ne 0) { throw 'Authenticate GitHub CLI with gh auth login.' }
$dist = Join-Path $root 'release-dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$oldVersion = [Environment]::GetEnvironmentVariable('VERSION', 'Process')
try {
    [Environment]::SetEnvironmentVariable('VERSION', $Version, 'Process')
    $assets = @()
    foreach ($side in @('CLIENT', 'SERVER')) {
        $folder = Join-Path $root $side
        if (-not $SkipBuild) {
            Push-Location $folder
            try {
                & .\gradlew.bat clean build reobfJar --no-daemon '-PdisableSpotless=true'
                if ($LASTEXITCODE -ne 0) { throw "$side build failed; release not published." }
            } finally { Pop-Location }
        }
        $name = "ae2stuff-$Version-$($side.ToLowerInvariant()).jar"
        $source = Join-Path (Join-Path $folder 'build\libs') $name
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Expected reobfuscated JAR not found: $source"
        }
        $target = Join-Path $dist $name
        Copy-Item -LiteralPath $source -Destination $target -Force
        $jar = [System.IO.Compression.ZipFile]::OpenRead($target)
        try {
            if ($jar.Entries.Count -eq 0) { throw "Empty JAR: $target" }
        } finally { $jar.Dispose() }
        $hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
        $hashFile = "$target.sha256"
        [System.IO.File]::WriteAllText($hashFile, "$hash  $name" + [Environment]::NewLine)
        $assets += $target
        $assets += $hashFile
        Write-Host "Ready: $name (SHA-256 $hash)"
    }
    $head = (& git -C $root rev-parse HEAD)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot determine project Git commit.' }
    $head = $head.Trim()
    & gh release view $Version --repo $Repository 2>$null | Out-Null
    $exists = $LASTEXITCODE -eq 0
    if ($exists) {
        & gh release upload $Version @assets --repo $Repository --clobber
    } else {
        & gh release create $Version @assets --repo $Repository --target $head --title "AE2 Stuff $Version" --notes 'Minecraft 1.7.10 CLIENT and SERVER runtime JARs with SHA-256 checksums.'
    }
    if ($LASTEXITCODE -ne 0) { throw 'Release publication failed.' }
    Write-Host "Published: https://github.com/$Repository/releases/tag/$Version"
} finally {
    [Environment]::SetEnvironmentVariable('VERSION', $oldVersion, 'Process')
}
