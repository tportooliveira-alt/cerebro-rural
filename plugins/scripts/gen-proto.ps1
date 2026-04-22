#!/usr/bin/env pwsh
# Gera os stubs Go do contrato ExtensionService.
# Requer: buf (https://buf.build) instalado e no PATH.

$ErrorActionPreference = "Stop"
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    buf generate
    Write-Host "Stubs gerados em plugins/proto/extension/v1/" -ForegroundColor Green
} finally {
    Pop-Location
}
