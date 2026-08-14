# server.ps1 — Einstiegspunkt: Pode-Webserver mit Dashboard, API und Wochen-Schedule.
# Start:  pwsh ./server.ps1        (Port aus settings.json, Standard 8080)

$ErrorActionPreference = 'Stop'
Import-Module Pode

$root = $PSScriptRoot
Import-Module (Join-Path $root 'src/Settings.psm1') -Force
$port = (Get-AppSettings).port

Start-PodeServer -RootPath $root {
    Add-PodeEndpoint -Address localhost -Port $port -Protocol Http

    # Module in allen Pode-Runspaces verfügbar machen
    Import-PodeModule -Path './src/Settings.psm1'
    Import-PodeModule -Path './src/Graph.psm1'
    Import-PodeModule -Path './src/Storage.psm1'
    Import-PodeModule -Path './src/App.psm1'

    Initialize-Database

    # ---------- Statisches Dashboard ----------
    Add-PodeStaticRoute -Path '/' -Source './public' -Defaults @('index.html')

    # ---------- API ----------
    Add-PodeRoute -Method Get -Path '/api/data' -ScriptBlock {
        try {
            Write-PodeJsonResponse -Value (Get-DashboardData) -Depth 6
        }
        catch {
            Write-PodeJsonResponse -StatusCode 500 -Value @{ error = "$_" }
        }
    }

    Add-PodeRoute -Method Get -Path '/api/settings' -ScriptBlock {
        $s = Get-AppSettings
        # Secret nie zurückgeben, nur ob eines gesetzt ist
        Write-PodeJsonResponse -Value @{
            tenantId     = $s.tenantId
            clientId     = $s.clientId
            secretSet    = [bool]$s.clientSecretEnc
            demoMode     = [bool]$s.demoMode
            port         = $s.port
            scheduleCron = $s.scheduleCron
        }
    }

    Add-PodeRoute -Method Post -Path '/api/settings' -ScriptBlock {
        try {
            $in = $WebEvent.Data
            $s = Get-AppSettings
            if ($null -ne $in.tenantId) { $s.tenantId = [string]$in.tenantId }
            if ($null -ne $in.clientId) { $s.clientId = [string]$in.clientId }
            if ($null -ne $in.demoMode) { $s.demoMode = [bool]$in.demoMode }
            if ($in.clientSecret) {
                $prot = Protect-ClientSecret -PlainSecret ([string]$in.clientSecret)
                $s.clientSecretEnc  = $prot.value
                $s.secretProtection = $prot.protection
            }
            Save-AppSettings -Settings $s
            Write-PodeJsonResponse -Value @{ ok = $true }
        }
        catch {
            Write-PodeJsonResponse -StatusCode 500 -Value @{ error = "$_" }
        }
    }

    Add-PodeRoute -Method Post -Path '/api/test' -ScriptBlock {
        try {
            $s = Get-AppSettings
            if ($s.demoMode) {
                Write-PodeJsonResponse -Value @{ ok = $true; message = 'Demo-Modus aktiv — kein Tenant-Zugriff nötig.' }
                return
            }
            $secret = Unprotect-ClientSecret -Settings $s
            $null = Get-GraphToken -TenantId $s.tenantId -ClientId $s.clientId -ClientSecret $secret
            Write-PodeJsonResponse -Value @{ ok = $true; message = 'Verbindung erfolgreich — Token erhalten.' }
        }
        catch {
            Write-PodeJsonResponse -StatusCode 500 -Value @{ error = "Verbindung fehlgeschlagen: $_" }
        }
    }

    Add-PodeRoute -Method Post -Path '/api/collect' -ScriptBlock {
        try {
            # Erfassungen serialisieren — parallele Läufe würden sich gegenseitig überschreiben
            $result = Lock-PodeObject -Object $WebEvent.Lockable -Return -ScriptBlock {
                Invoke-UsageCollection
            }
            Write-PodeJsonResponse -Value $result
        }
        catch {
            Write-PodeJsonResponse -StatusCode 500 -Value @{ error = "$_" }
        }
    }

    # ---------- Wöchentliche Erfassung ----------
    $cron = (Get-AppSettings).scheduleCron
    Add-PodeSchedule -Name 'WeeklyCollection' -Cron $cron -ScriptBlock {
        try {
            $r = Lock-PodeObject -Object $Event.Lockable -Return -ScriptBlock {
                Invoke-UsageCollection
            }
            Write-PodeHost "Geplante Erfassung ok: $($r.users) Benutzer, Snapshot $($r.date)"
        }
        catch {
            Write-PodeHost "Geplante Erfassung fehlgeschlagen: $_"
        }
    }

    Write-PodeHost "M365 Usage Dashboard läuft auf http://localhost:$port"
}
