$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..')).Path
$VenvPath = Join-Path $RepoRoot '.venv'

function Ensure-Repo {
    if (-not (Test-Path (Join-Path $RepoRoot 'AdminWebpage')) -or -not (Test-Path (Join-Path $RepoRoot 'RiderWebpage')) -or -not (Test-Path (Join-Path $RepoRoot 'DriverWebpage'))) {
        Write-Host "Could not find repo at: $RepoRoot"
        Write-Host "Expected layout:"
        Write-Host "  ridematch/"
        Write-Host "  ├── scripts/"
        Write-Host "  ├── AdminWebpage/"
        Write-Host "  ├── RiderWebpage/"
        Write-Host "  └── DriverWebpage/"
        exit 1
    }
}

function Get-PythonCommand {
    foreach ($candidate in @('py', 'python')) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            return $candidate
        }
    }

    throw 'Could not find Python. Install Python first.'
}

Ensure-Repo
Set-Location $RepoRoot

$PythonCommand = Get-PythonCommand

if (-not (Test-Path $VenvPath)) {
    Write-Host "Creating virtual environment at $VenvPath with $PythonCommand..."
    & $PythonCommand -m venv $VenvPath
}

$VenvPython = Join-Path (Join-Path $VenvPath 'Scripts') 'python.exe'
& $VenvPython -m pip install --upgrade pip setuptools wheel

if (Test-Path (Join-Path $RepoRoot 'requirements.txt')) {
    Write-Host 'Installing root requirements.txt...'
    & $VenvPython -m pip install -r (Join-Path $RepoRoot 'requirements.txt')
}

if (Test-Path (Join-Path (Join-Path $RepoRoot 'AdminWebpage') 'requirements.txt')) {
    Write-Host 'Installing AdminWebpage requirements...'
    & $VenvPython -m pip install -r (Join-Path (Join-Path $RepoRoot 'AdminWebpage') 'requirements.txt')
}

if (Get-Command flutter -ErrorAction SilentlyContinue) {
    foreach ($mobileApp in @('ridermobile', 'drivermobile')) {
        $mobilePath = Join-Path $RepoRoot $mobileApp
        if (Test-Path $mobilePath) {
            Write-Host "Running flutter pub get for $mobileApp..."
            Push-Location $mobilePath
            try {
                & flutter pub get
            }
            finally {
                Pop-Location
            }
        }
    }
}

Write-Host ''
Write-Host 'Setup complete.'
Write-Host "Virtual environment location: $VenvPath"
Write-Host 'Run the other scripts from the scripts folder when you are ready.'