# Settings.psm1 — Laden/Speichern der App-Einstellungen inkl. Client-Secret-Schutz.
# Unter Windows wird das Secret per DPAPI (benutzergebunden) verschlüsselt,
# auf anderen Plattformen (nur Entwicklung) Base64-kodiert abgelegt.

$script:SettingsPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'settings.json'

# Server-seitige Meldungen in der eingestellten Sprache
$script:Texts = @{
    de = @{
        demoActive    = 'Demo-Modus aktiv — kein Tenant-Zugriff nötig.'
        connOk        = 'Verbindung erfolgreich — Token erhalten.'
        connFail      = 'Verbindung fehlgeschlagen: '
        notConfigured = 'Tenant nicht konfiguriert. Bitte zuerst Tenant-ID, Client-ID und Client-Secret hinterlegen.'
        emptyReport   = 'Report war leer — keine Benutzerdaten erhalten.'
    }
    en = @{
        demoActive    = 'Demo mode active — no tenant access required.'
        connOk        = 'Connection successful — token received.'
        connFail      = 'Connection failed: '
        notConfigured = 'Tenant not configured. Please enter tenant ID, client ID and client secret first.'
        emptyReport   = 'Report was empty — no user data received.'
    }
}

function Get-Text {
    param([Parameter(Mandatory)][string]$Key)
    $lang = (Get-AppSettings).language
    if ($lang -ne 'en') { $lang = 'de' }
    $script:Texts[$lang][$Key]
}

function Get-AppSettings {
    $defaults = [ordered]@{
        tenantId         = ''
        clientId         = ''
        clientSecretEnc  = ''
        secretProtection = ''      # 'dpapi' | 'plain'
        demoMode         = $false
        language         = 'de'    # 'de' | 'en'
        port             = 8080
        scheduleCron     = '0 6 * * 1'  # montags 06:00
    }
    if (Test-Path $script:SettingsPath) {
        $saved = Get-Content $script:SettingsPath -Raw | ConvertFrom-Json
        foreach ($p in $saved.PSObject.Properties) {
            if ($defaults.Contains($p.Name)) { $defaults[$p.Name] = $p.Value }
        }
    }
    [pscustomobject]$defaults
}

function Save-AppSettings {
    param([Parameter(Mandatory)][pscustomobject]$Settings)
    $Settings | ConvertTo-Json | Set-Content $script:SettingsPath -Encoding utf8
    if ($IsWindows) {
        # Datei nur für den ausführenden Benutzer lesbar machen
        icacls $script:SettingsPath /inheritance:r /grant:r "$($env:USERNAME):(F)" | Out-Null
    }
    else {
        chmod 600 $script:SettingsPath
    }
}

function Protect-ClientSecret {
    param([Parameter(Mandatory)][string]$PlainSecret)
    if ($IsWindows) {
        $sec = ConvertTo-SecureString $PlainSecret -AsPlainText -Force
        return @{ value = ($sec | ConvertFrom-SecureString); protection = 'dpapi' }
    }
    # Entwicklung auf macOS/Linux: kein DPAPI verfügbar
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($PlainSecret))
    return @{ value = $b64; protection = 'plain' }
}

function Unprotect-ClientSecret {
    param([Parameter(Mandatory)][pscustomobject]$Settings)
    if (-not $Settings.clientSecretEnc) { return '' }
    switch ($Settings.secretProtection) {
        'dpapi' {
            $sec = $Settings.clientSecretEnc | ConvertTo-SecureString
            return [System.Net.NetworkCredential]::new('', $sec).Password
        }
        'plain' {
            return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Settings.clientSecretEnc))
        }
        default { return '' }
    }
}

Export-ModuleMember -Function Get-AppSettings, Save-AppSettings, Protect-ClientSecret, Unprotect-ClientSecret, Get-Text
