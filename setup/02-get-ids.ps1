# 02-get-ids.ps1 — liest die für das Dashboard nötigen IDs aus dem Tenant aus
# und prüft, ob die App-Registrierung vollständig ist (Berechtigungen, Consent,
# Secret-Ablauf). Ein neues Secret kann dieses Script nicht anzeigen — Secrets
# sind nur bei der Erstellung sichtbar (bei Bedarf 01-register-app.ps1 bzw.
# Portal: Zertifikate & Geheimnisse -> neues Secret).
#
# Voraussetzungen:
#   Install-Module Microsoft.Graph.Applications -Scope CurrentUser

$ErrorActionPreference = 'Stop'
$appName = 'Speicher-Dashboard'   # ggf. an den gewählten App-Namen anpassen

Import-Module Microsoft.Graph.Applications
Connect-MgGraph -Scopes 'Application.Read.All' -NoWelcome

$tenantId = (Get-MgContext).TenantId
Write-Host "Tenant-ID: $tenantId" -ForegroundColor Green

$app = Get-MgApplication -Filter "displayName eq '$appName'"
if (-not $app) {
    Write-Host "Keine App-Registrierung '$appName' gefunden." -ForegroundColor Yellow
    Write-Host 'Vorhandene App-Registrierungen:'
    Get-MgApplication -All | Select-Object DisplayName, AppId | Format-Table
    return
}
Write-Host "Client-ID: $($app.AppId)" -ForegroundColor Green

# Secret-Laufzeiten
if ($app.PasswordCredentials) {
    Write-Host ''
    Write-Host 'Client-Secrets:'
    $app.PasswordCredentials | ForEach-Object {
        $status = if ($_.EndDateTime -lt (Get-Date)) { 'ABGELAUFEN' }
                  elseif ($_.EndDateTime -lt (Get-Date).AddDays(60)) { 'läuft bald ab' }
                  else { 'gültig' }
        $until = $_.EndDateTime.ToString('yyyy-MM-dd')
        Write-Host ("  {0}  bis {1}  [{2}]" -f $_.DisplayName, $until, $status)
    }
}
else {
    Write-Host 'Kein Client-Secret vorhanden —' -ForegroundColor Yellow
    Write-Host 'im Portal oder mit 01-register-app.ps1 erstellen.' -ForegroundColor Yellow
}

# Berechtigungen + Admin-Consent prüfen
$required = 'Reports.Read.All', 'User.Read.All', 'Organization.Read.All'
$graphSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
$sp = Get-MgServicePrincipal -Filter "appId eq '$($app.AppId)'"
$granted = @()
if ($sp) {
    $granted = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id |
        ForEach-Object { ($graphSp.AppRoles | Where-Object Id -eq $_.AppRoleId).Value }
}
Write-Host ''
Write-Host 'Berechtigungen (Admin-Consent):'
foreach ($r in $required) {
    $ok = $granted -contains $r
    $mark = if ($ok) { 'OK ' } else { 'FEHLT' }
    $color = if ($ok) { 'Green' } else { 'Red' }
    Write-Host ("  [{0}] {1}" -f $mark, $r) -ForegroundColor $color
}
if (-not $sp) {
    Write-Host '  Kein Service Principal —' -ForegroundColor Red
    Write-Host '  im Portal einmal Admin-Consent erteilen.' -ForegroundColor Red
}
