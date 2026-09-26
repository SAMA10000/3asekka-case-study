$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $RepoRoot

Write-Host ""
Write-Host "=== 3ASEKKA AI Transport Agent ===" -ForegroundColor Cyan
Write-Host "Updating the demo..." -ForegroundColor Yellow

try {
    git pull --ff-only
} catch {
    Write-Host "Could not auto-update. Starting the local copy." -ForegroundColor Yellow
}

Set-Location $PSScriptRoot

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js 18+ is required."
}

Write-Host "Opening 3ASEKKA demo..." -ForegroundColor Green
Start-Process "http://localhost:3000"
node .\server.mjs
