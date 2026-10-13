param(
    [string]$PotiRoot = 'C:\Modlists\POTI',
    [switch]$PrepareOnly,
    [switch]$SmokeTest
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$copyRoot = Join-Path $projectRoot '.runtime\kyne-source'

function Copy-TestDependency([string]$Source, [string]$Destination, [string[]]$Exclude = @()) {
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw "Missing source: $Source" }
    Write-Host "Copying test dependency: $Source"
    $copyArgs = @($Source, $Destination, '/E', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/XJ')
    if ($Exclude.Count) { $copyArgs += '/XF'; $copyArgs += $Exclude }
    & robocopy @copyArgs
    if ($LASTEXITCODE -ge 8) { throw "Dependency copy failed: $Source (robocopy $LASTEXITCODE)" }
}

# All destinations belong to this test project; source installations are read-only.
Copy-TestDependency (Join-Path $PotiRoot '.OpenMW') (Join-Path $copyRoot 'engine') @('*.zip')
Copy-TestDependency (Join-Path $PotiRoot 'mods\Tamriel_Data (HD)') (Join-Path $copyRoot 'tamriel-data')
Copy-TestDependency (Join-Path $PotiRoot 'mods\Skyrim Home Of The Nords') (Join-Path $copyRoot 'skyrim')
& (Join-Path $PSScriptRoot 'start-test.ps1') -Engine (Join-Path $copyRoot 'engine\openmw.exe') `
    -KyneData $copyRoot -PrepareOnly:$PrepareOnly -SmokeTest:$SmokeTest
