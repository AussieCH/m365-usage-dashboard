# stop.ps1 — beendet den Dashboard-Server (über die PID-Datei aus start.ps1).

$root    = $PSScriptRoot
$pidFile = Join-Path $root 'data/server.pid'

$stopped = $false

if (Test-Path $pidFile) {
    $serverPid = Get-Content $pidFile
    $proc = Get-Process -Id $serverPid -ErrorAction SilentlyContinue
    if ($proc) {
        Stop-Process -Id $proc.Id -Force
        Write-Host "Server beendet (PID $($proc.Id))."
        $stopped = $true
    }
    Remove-Item $pidFile
}

if (-not $stopped) {
    # Fallback: pwsh-Prozess suchen, der unser server.ps1 ausführt
    $serverScript = Join-Path $root 'server.ps1'
    $candidates = Get-Process pwsh -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*$serverScript*" -and $_.Id -ne $PID }
    if ($candidates) {
        $candidates | Stop-Process -Force
        Write-Host "Server beendet (PID $($candidates.Id -join ', '))."
    }
    else {
        Write-Host 'Kein laufender Server gefunden.'
    }
}
