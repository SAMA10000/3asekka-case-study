$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host ""
Write-Host "=== 3ASEKKA AI Transport Agent ===" -ForegroundColor Cyan

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw "Node.js 18+ is required."
}

Write-Host "Starting demo on http://localhost:3000 ..." -ForegroundColor Green
Start-Process "http://localhost:3000"
node .\server.mjs
