# 01-register-app.ps1 — legt die App-Registrierung für das Speicher-Dashboard
# vollautomatisch an: App + Service Principal, Graph-Berechtigungen inkl.
# Admin-Consent, Client-Secret (24 Monate). Gibt am Ende die drei Werte aus,
# die im Dashboard unter Einstellungen eingetragen werden.
#
# Voraussetzungen:
#   Install-Module Microsoft.Graph.Applications -Scope CurrentUser
#   Ausführung als Global Administrator (oder Privileged Role Admin + App Admin)
#
# Aufruf:  ./01-register-app.ps1                          (Standardname)
#          ./01-register-app.ps1 -AppName 'Mein Name'     (eigener App-Name)

param([string]$AppName = 'Speicher-Dashboard')

$ErrorActionPreference = 'Stop'
$appName = $AppName

Import-Module Microsoft.Graph.Applications
Connect-MgGraph -Scopes 'Application.ReadWrite.All', 'AppRoleAssignment.ReadWrite.All' -NoWelcome

# Microsoft-Graph-Anwendungsberechtigungen (App-Rollen, IDs sind global fix)
$graphAppId = '00000003-0000-0000-c000-000000000000'
$roles = [ordered]@{
    'Reports.Read.All'      = '230c1aed-a721-4c5d-9cb4-a90514e508ef'  # Pflicht: Usage-Reports
    'User.Read.All'         = 'df021288-bdef-4463-88db-98f22de89214'  # optional: Lizenzen
    'Organization.Read.All' = '498476ce-e0fe-48b0-b801-37ba7e2685c6'  # optional: SKU-Namen
    'Sites.Read.All'        = '332a536c-c7ef-4017-ab91-336970924f0d'  # optional: Website-Namen
}

$existing = Get-MgApplication -Filter "displayName eq '$appName'"
if ($existing) {
    Write-Host "Es existiert bereits eine App-Registrierung '$appName':" -ForegroundColor Yellow
    Write-Host "  AppId $($existing.AppId)"
    Write-Host 'Abbruch — zum Auslesen der Werte 02-get-ids.ps1 verwenden.'
    return
}

Write-Host "Erstelle App-Registrierung '$appName' ..."
$access = @{
    resourceAppId  = $graphAppId
    resourceAccess = @($roles.Values | ForEach-Object { @{ id = $_; type = 'Role' } })
}
$app = New-MgApplication -DisplayName $appName -SignInAudience 'AzureADMyOrg' `
    -RequiredResourceAccess @($access)

Write-Host 'Erstelle Service Principal ...'
$sp = New-MgServicePrincipal -AppId $app.AppId

Write-Host 'Erteile Admin-Consent für die Graph-Berechtigungen ...'
$graphSp = Get-MgServicePrincipal -Filter "appId eq '$graphAppId'"
foreach ($name in $roles.Keys) {
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id `
        -PrincipalId $sp.Id -ResourceId $graphSp.Id -AppRoleId $roles[$name] | Out-Null
    Write-Host "  + $name"
}

Write-Host 'Erstelle Client-Secret (Laufzeit 24 Monate) ...'
$secret = Add-MgApplicationPassword -ApplicationId $app.Id -PasswordCredential @{
    displayName = 'Dashboard'
    endDateTime = (Get-Date).AddMonths(24)
}

$tenantId = (Get-MgContext).TenantId

Write-Host ''
Write-Host '=== Diese Werte im Dashboard unter Einstellungen eintragen ===' -ForegroundColor Green
[pscustomobject]@{
    'Tenant-ID'     = $tenantId
    'Client-ID'     = $app.AppId
    'Client-Secret' = $secret.SecretText
    'Secret-Ablauf' = $secret.EndDateTime.ToString('yyyy-MM-dd')
} | Format-List
Write-Host 'Das Secret ist nur jetzt sichtbar — sofort kopieren!' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Hinweis: Neu erteilte Berechtigungen brauchen einige Minuten, bis sie in'
Write-Host 'den Tokens ankommen. Meldet das Dashboard anfangs 403-Fehler oder fehlende'
Write-Host 'Website-Namen, einfach 5-15 Minuten warten und erneut erfassen.'
