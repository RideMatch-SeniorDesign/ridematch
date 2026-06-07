$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..')).Path
$VenvPath = Join-Path $RepoRoot '.venv'
$VenvPython = Join-Path (Join-Path $VenvPath 'Scripts') 'python.exe'

if (-not (Test-Path $VenvPython)) {
    Write-Host "No virtual environment found at $VenvPath"
    Write-Host 'Run .\scripts\setup_env.ps1 first.'
    exit 1
}

Set-Location $RepoRoot
& $VenvPython (Join-Path (Join-Path $RepoRoot 'AdminWebpage') 'app.py')