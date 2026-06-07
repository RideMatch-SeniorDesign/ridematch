$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir '..')

if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Host "VS Code 'code' command is not in PATH."
    Write-Host "Open VS Code and run: Shell Command: Install 'code' command in PATH"
    exit 1
}

Set-Location $RepoRoot
& code .