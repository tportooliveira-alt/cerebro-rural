#!/usr/bin/env pwsh
# Compila host e plugin de exemplo.
$ErrorActionPreference = "Stop"
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    New-Item -ItemType Directory -Force -Path bin | Out-Null
    go build -o bin/cerebro-host.exe ./host/cmd/cerebro-host
    go build -o bin/hello.exe        ./examples/hello
    Write-Host "OK: bin/cerebro-host.exe e bin/hello.exe" -ForegroundColor Green
} finally {
    Pop-Location
}
