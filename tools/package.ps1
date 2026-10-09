param([string]$Python = 'python')
$ErrorActionPreference = 'Stop'
$builder = Join-Path $PSScriptRoot 'package.py'
& $Python $builder
if ($LASTEXITCODE -ne 0) { throw 'Production package build failed' }
& $Python $builder --test
if ($LASTEXITCODE -ne 0) { throw 'Test package build failed' }
