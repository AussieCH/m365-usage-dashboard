# start.ps1 — startet den Dashboard-Server im Hintergrund.
# PID wird in data/server.pid abgelegt, Ausgabe landet in data/server.log.

$ErrorActionPreference = 'Stop'
$root    = $PSScriptRoot
$dataDir = Join-Path $root 'data'
$pidFile = Join-Path $dataDir 'server.pid'
$logFile = Join-Path $dataDir 'server.log'
$errFile = Join-Path $dataDir 'server.err.log'

if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir | Out-Null }

# Läuft schon?
if (Test-Path $pidFile) {
    $existing = Get-Process -Id (Get-Content $pidFile) -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Server läuft bereits (PID $($existing.Id))."
        exit 0
    }
    Remove-Item $pidFile   # verwaiste PID-Datei aufräumen
}

$proc = Start-Process pwsh `
    -ArgumentList '-NoProfile', '-File', (Join-Path $root 'server.ps1') `
    -WorkingDirectory $root `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError $errFile `
    -PassThru

$proc.Id | Set-Content $pidFile

# Kurz warten und prüfen, ob der Start geklappt hat
Start-Sleep -Seconds 3
if ($proc.HasExited) {
    Remove-Item $pidFile -ErrorAction SilentlyContinue
    Write-Host 'Serverstart fehlgeschlagen — letzte Logzeilen:' -ForegroundColor Red
    Get-Content $errFile -Tail 15 -ErrorAction SilentlyContinue
    Get-Content $logFile -Tail 15 -ErrorAction SilentlyContinue
    exit 1
}

Import-Module (Join-Path $root 'src/Settings.psm1')
$port = (Get-AppSettings).port
Write-Host "Server gestartet (PID $($proc.Id)) — http://localhost:$port"
