param(
    [string]$Engine = 'C:\Modlists\POTI\.OpenMW\openmw.exe',
    [string]$GameData = 'D:\Steam\steamapps\common\Morrowind\Data Files',
    [switch]$PrepareOnly,
    [switch]$SmokeTest,
    [switch]$PotiShaders,
    [string]$PureMultiMarkArchive,
    [string]$DaisyMultiMarkArchive,
    [string]$KyneData,
    [string]$PotiProfile = 'C:\Modlists\POTI\profiles\Path of the Incarnate - Standard'
)
$ErrorActionPreference = 'Stop'
if ($PureMultiMarkArchive -and $DaisyMultiMarkArchive) {
    throw 'Test the two Multi Mark implementations in separate sessions.'
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = (Resolve-Path -LiteralPath $Engine).Path
$gamePath = (Resolve-Path -LiteralPath $GameData).Path
$resourcesPath = Join-Path (Split-Path -Parent $enginePath) 'resources'
$version = (Get-Content -LiteralPath (Join-Path $resourcesPath 'version') -TotalCount 1).Trim()
if ($version -notmatch '^0\.52\.') { throw "This test targets OpenMW 0.52; found $version" }
if (-not $PrepareOnly -and (Get-Process -Name openmw -ErrorAction SilentlyContinue)) {
    throw 'Close the running OpenMW game before starting this test.'
}
foreach ($file in @('Morrowind.esm', 'Morrowind.bsa')) {
    if (-not (Test-Path -LiteralPath (Join-Path $gamePath $file) -PathType Leaf)) { throw "Missing $file" }
}
foreach ($file in @('TeleportTransitionTest.omwscripts', 'TeleportTransitionSmoke.omwscripts',
    'Shaders\teleport_transition.omwfx', 'scripts\teleport_transition\player.lua',
    'scripts\teleport_transition\test_fixtures.lua', 'scripts\teleport_transition\test_player.lua',
    'scripts\teleport_transition\test_smoke.lua')) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $file) -PathType Leaf)) { throw "Missing $file" }
}
$name = if ($SmokeTest) { 'smoke' } else { 'manual' }
if ($PotiShaders) { $name = 'poti-shaders-' + $name }
if ($PureMultiMarkArchive) { $name = 'puremultimark-' + $name }
if ($DaisyMultiMarkArchive) { $name = 'daisymultimark-' + $name }
if ($KyneData) { $name = 'kyne-' + $name }
$profilePath = Join-Path $projectRoot ".runtime\$name-profile"
$userDataPath = Join-Path $projectRoot ".runtime\$name-user-data"
$localDataPath = Join-Path $userDataPath 'data'
New-Item -ItemType Directory -Force -Path $profilePath,$userDataPath,$localDataPath | Out-Null
$lines = @(
    'replace=config', 'replace=data', 'replace=content', 'replace=groundcover',
    'replace=fallback-archive',
    ('resources="' + $resourcesPath.Replace('\','/') + '"'),
    ('data="' + $resourcesPath.Replace('\','/') + '/vfs-mw"'),
    ('data="' + $gamePath.Replace('\','/') + '"'),
    ('data-local="' + $localDataPath.Replace('\','/') + '"'),
    'content=Morrowind.esm', 'fallback-archive=Morrowind.bsa',
    'content=TeleportTransitionTest.omwscripts'
)
$chain = ''
if ($DaisyMultiMarkArchive) {
    $daisyZip = (Resolve-Path -LiteralPath $DaisyMultiMarkArchive).Path
    $daisyData = Join-Path $projectRoot '.runtime\daisymultimark-source'
    Expand-Archive -LiteralPath $daisyZip -DestinationPath $daisyData -Force
    if (-not (Test-Path -LiteralPath (Join-Path $daisyData 'LuaMultiMark.omwscripts'))) {
        throw 'The archive must contain LuaMultiMark.omwscripts at its root'
    }
    $lines += 'data="' + $daisyData.Replace('\','/') + '"'
    $lines += @('content=LuaMultiMark.omwscripts', 'content=TeleportTransitionDaisyTest.omwscripts')
}
if ($KyneData) {
    $kyneRoot = (Resolve-Path -LiteralPath $KyneData).Path
    foreach ($entry in @('tamriel-data\Tamriel_Data.esm', 'tamriel-data\Tamriel_Data.omwscripts',
        'skyrim\Sky_Main.ESM')) {
        if (-not (Test-Path -LiteralPath (Join-Path $kyneRoot $entry))) { throw "Missing copied Kyne dependency: $entry" }
    }
    $lines += 'data="' + (Join-Path $kyneRoot 'tamriel-data').Replace('\','/') + '"'
    $lines += 'data="' + (Join-Path $kyneRoot 'skyrim').Replace('\','/') + '"'
    $lines += @('content=Tribunal.esm', 'content=Bloodmoon.esm', 'content=Tamriel_Data.esm',
        'content=Sky_Main.ESM', 'content=Tamriel_Data.omwscripts', 'content=TeleportTransitionKyneTest.omwscripts')
}
if ($PureMultiMarkArchive) {
    $multiMarkZip = (Resolve-Path -LiteralPath $PureMultiMarkArchive).Path
    $multiMarkExtract = Join-Path $projectRoot '.runtime\puremultimark-source'
    Expand-Archive -LiteralPath $multiMarkZip -DestinationPath $multiMarkExtract -Force
    $multiMarkData = Join-Path $multiMarkExtract 'puremultimark'
    if (-not (Test-Path -LiteralPath (Join-Path $multiMarkData 'puremultimark.omwscripts'))) {
        throw 'The archive must contain puremultimark/puremultimark.omwscripts'
    }
    $lines += 'data="' + $multiMarkData.Replace('\','/') + '"'
    $lines += 'content=puremultimark.omwscripts'
}
if ($PotiShaders) {
    $potiConfig = Join-Path $PotiProfile 'openmw.cfg'
    $potiSettings = Join-Path $PotiProfile 'settings.cfg'
    foreach ($path in @($potiConfig, $potiSettings)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing POTI profile file: $path" }
    }
    # Load shader-bearing data roots only; do not import POTI's gameplay content or configs.
    foreach ($line in Get-Content -LiteralPath $potiConfig) {
        if ($line -match '^\s*data\s*=\s*"([^"]+)"\s*$') {
            $dataRoot = $Matches[1]
            if (Test-Path -LiteralPath (Join-Path $dataRoot 'Shaders') -PathType Container) {
                $lines += 'data="' + $dataRoot.Replace('\','/') + '"'
            }
        }
    }
    $section = ''
    foreach ($line in Get-Content -LiteralPath $potiSettings) {
        if ($line -match '^\s*\[([^\]]+)\]') { $section = $Matches[1] }
        elseif ($section -eq 'Post Processing' -and $line -match '^\s*chain\s*=\s*(.*)$') {
            $chain = $Matches[1].Trim()
        }
    }
    if (-not $chain) { throw 'POTI Post Processing chain is empty or missing' }
    $chain = (($chain -split ',' | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -notin @('teleport_transition', 'incarnate_clarity', 'night_eye_comfort') }) -join ',')
}
# Our workspace shader wins over any older installed copy.
$lines += 'data="' + $projectRoot.Replace('\','/') + '"'
foreach ($archive in @('Tribunal.bsa', 'Bloodmoon.bsa')) {
    if (Test-Path -LiteralPath (Join-Path $gamePath $archive) -PathType Leaf) {
        $lines += 'fallback-archive=' + $archive
    }
}
if ($SmokeTest) {
    $lines += if ($DaisyMultiMarkArchive) { 'content=TeleportTransitionDaisySmoke.omwscripts' }
        else { 'content=TeleportTransitionSmoke.omwscripts' }
}
[IO.File]::WriteAllLines((Join-Path $profilePath 'openmw.cfg'), $lines)
$settingsPath = Join-Path $profilePath 'settings.cfg'
if ($SmokeTest -or -not (Test-Path -LiteralPath $settingsPath)) {
    if ($PotiShaders -and (Test-Path -LiteralPath (Join-Path $PotiProfile 'shaders.yaml'))) {
        Copy-Item -LiteralPath (Join-Path $PotiProfile 'shaders.yaml') -Destination (Join-Path $profilePath 'shaders.yaml')
    }
    $volume = if ($SmokeTest) { 0 } else { 1 }
    [IO.File]::WriteAllText($settingsPath, @"
[Video]
resolution x = 1280
resolution y = 720
fullscreen = false
vsync = false
[Sound]
music volume = 0
master volume = $volume
[Post Processing]
enabled = true
chain = $chain
"@)
}
Write-Host "OpenMW $version test profile: $profilePath"
Write-Host "Logs: $profilePath\openmw.log"
Write-Host "Test saves and Lua storage: $userDataPath"
$startCell = if ($KyneData) { 'Karthgad' } else { 'Seyda Neen' }
Write-Host "Fresh session starts in $startCell. Read TESTING.md for commands and checks."
if ($PotiShaders) { Write-Host "POTI shader-chain mode (not full modlist): $chain" }
if ($PureMultiMarkArchive) { Write-Host "Pure Lua Multi Mark enabled from: $multiMarkZip" }
if ($PrepareOnly) { return }
$arguments = @('--replace', 'config', '--config', ('"' + $profilePath + '"'),
    '--user-data', ('"' + $userDataPath + '"'), '--skip-menu', '--new-game=0',
    '--start', ('"' + $startCell + '"'), '--no-grab')
if ($SmokeTest) {
    $process = Start-Process -FilePath $enginePath -WorkingDirectory (Split-Path -Parent $enginePath) `
        -WindowStyle Hidden -ArgumentList $arguments -PassThru
    if (-not $process.WaitForExit(60000)) {
        $process.Kill()
        $process.WaitForExit()
        throw "Smoke test timed out. See $profilePath\openmw.log"
    }
    $log = Get-Content -LiteralPath (Join-Path $profilePath 'openmw.log') -Raw
    if ($process.ExitCode -ne 0 -or $log -notmatch 'TT_SMOKE_PASS' -or $log -match 'TT_SMOKE_FAIL| E\]') {
        throw "Smoke test failed. See $profilePath\openmw.log"
    }
    Write-Host 'TT_SMOKE_PASS: supplies, settings, shader preview, and cleanup checked.'
} else {
    Start-Process -FilePath $enginePath -WorkingDirectory (Split-Path -Parent $enginePath) `
        -WindowStyle Normal -ArgumentList $arguments
}
