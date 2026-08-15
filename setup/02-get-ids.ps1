# 02-get-ids.ps1 — liest die für das Dashboard nötigen IDs aus dem Tenant aus
# und prüft, ob die App-Registrierung vollständig ist (Berechtigungen, Consent,
# Secret-Ablauf). Ein neues Secret kann dieses Script nicht anzeigen — Secrets
# sind nur bei der Erstellung sichtbar (bei Bedarf 01-register-app.ps1 bzw.
# Portal: Zertifikate & Geheimnisse -> neues Secret).
#
# Voraussetzungen:
#   Install-Module Microsoft.Graph.Applications -Scope CurrentUser
#
# Aufruf:  ./02-get-ids.ps1                          (Standardname)
#          ./02-get-ids.ps1 -AppName 'Mein Name'     (eigener App-Name)
#          ./02-get-ids.ps1 -Fix                     (fehlende Berechtigungen direkt zuweisen)

param([string]$AppName = 'Speicher-Dashboard', [switch]$Fix)

$ErrorActionPreference = 'Stop'
$appName = $AppName

Import-Module Microsoft.Graph.Applications
$scopes = @('Application.Read.All')
if ($Fix) { $scopes += 'AppRoleAssignment.ReadWrite.All' }
Connect-MgGraph -Scopes $scopes -NoWelcome

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
$required = 'Reports.Read.All', 'User.Read.All', 'Organization.Read.All', 'Sites.Read.All'
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

# Fehlende Zuweisungen direkt reparieren (-Fix). Direkte App-Rollen-Zuweisung ist
# zuverlässiger als der Consent-Knopf im Portal, der bestehende Zuweisungen
# zurücksetzen kann.
$missing = @($required | Where-Object { $granted -notcontains $_ })
if ($Fix -and $missing.Count -gt 0 -and $sp) {
    $roleIds = @{
        'Reports.Read.All'      = '230c1aed-a721-4c5d-9cb4-a90514e508ef'
        'User.Read.All'         = 'df021288-bdef-4463-88db-98f22de89214'
        'Organization.Read.All' = '498476ce-e0fe-48b0-b801-37ba7e2685c6'
        'Sites.Read.All'        = '332a536c-c7ef-4017-ab91-336970924f0d'
    }
    Write-Host ''
    Write-Host 'Weise fehlende Berechtigungen zu ...'
    foreach ($m in $missing) {
        New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id `
            -PrincipalId $sp.Id -ResourceId $graphSp.Id -AppRoleId $roleIds[$m] | Out-Null
        Write-Host "  + $m" -ForegroundColor Green
    }
    Write-Host 'Fertig — neue Tokens enthalten die Rollen innert weniger Minuten.'
}
elseif ($missing.Count -gt 0 -and -not $Fix) {
    Write-Host ''
    Write-Host 'Tipp: ./02-get-ids.ps1 -Fix weist die fehlenden Berechtigungen direkt zu.' -ForegroundColor Yellow
}
