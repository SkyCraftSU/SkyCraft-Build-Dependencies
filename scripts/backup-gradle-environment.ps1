[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceProject,

    [Parameter(Mandatory = $true)]
    [string]$Destination,

    [string]$GradleHome = $(if ($env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME } else { Join-Path $env:USERPROFILE '.gradle' })
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SourceProject))
$destinationRoot = [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination))
$gradleHomeRoot = [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($GradleHome))

if (-not (Test-Path -LiteralPath $projectRoot -PathType Container)) { throw "Project not found: $projectRoot" }
if (-not (Test-Path -LiteralPath $gradleHomeRoot -PathType Container)) { throw "Gradle home not found: $gradleHomeRoot" }
if ($destinationRoot.StartsWith($gradleHomeRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Destination cannot be inside Gradle home.' }
if ($destinationRoot.StartsWith($projectRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Destination cannot be inside the source project.' }

New-Item -ItemType Directory -Force -Path $destinationRoot | Out-Null

function Copy-Tree([string]$Source, [string]$Target) {
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        Write-Host "Skipping missing directory: $Source"
        return
    }
    New-Item -ItemType Directory -Force -Path $Target | Out-Null
    & robocopy.exe $Source $Target /E /XJ /R:1 /W:1 /NP /NFL /NDL
    if ($LASTEXITCODE -ge 8) { throw "Robocopy failed ($LASTEXITCODE): $Source" }
}

$backupGradleHome = Join-Path $destinationRoot 'gradle-home'
foreach ($name in @('caches','wrapper','jdks')) {
    Copy-Tree (Join-Path $gradleHomeRoot $name) (Join-Path $backupGradleHome $name)
}

$projectCache = Join-Path $destinationRoot 'project-cache'
foreach ($side in @('CLIENT','SERVER')) {
    $sideCache = Join-Path (Join-Path $projectRoot $side) '.gradle'
    Copy-Tree $sideCache (Join-Path $projectCache $side)
}

$commit = (& git -C $projectRoot rev-parse HEAD 2>$null)
$manifest = @(
    'SkyCraft Gradle build environment backup'
    "Created UTC: $([DateTime]::UtcNow.ToString('u'))"
    "Source project: $projectRoot"
    "Git commit: $commit"
    "Original Gradle home: $gradleHomeRoot"
    'Contains: Gradle caches, wrapper distributions, JDK toolchains, CLIENT/SERVER project caches.'
    'Excludes: credentials, environment variables, user gradle.properties and init scripts.'
)
Set-Content -LiteralPath (Join-Path $destinationRoot 'BACKUP-MANIFEST.txt') -Value $manifest -Encoding UTF8

Write-Host "Backup complete: $destinationRoot"
