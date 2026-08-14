# 03-report-settings.ps1 — prüft die Pseudonymisierung der Microsoft-365-Berichte
# und schaltet sie auf Wunsch ab, damit das Dashboard Klarnamen und Site-URLs
# statt Hashes erhält. (Entspricht Admin Center: Einstellungen ->
# Organisationseinstellungen -> Berichte.)
#
# Voraussetzungen:
#   Install-Module Microsoft.Graph.Reports -Scope CurrentUser

$ErrorActionPreference = 'Stop'

Import-Module Microsoft.Graph.Reports
Connect-MgGraph -Scopes 'ReportSettings.ReadWrite.All' -NoWelcome

$settings = Get-MgAdminReportSetting
if ($settings.DisplayConcealedNames) {
    Write-Host 'Berichte sind aktuell PSEUDONYMISIERT (Hashes statt Namen).' -ForegroundColor Yellow
    $answer = Read-Host 'Pseudonymisierung jetzt abschalten? (j/n)'
    if ($answer -eq 'j') {
        Update-MgAdminReportSetting -BodyParameter @{ displayConcealedNames = $false }
        Write-Host 'Erledigt — Berichte zeigen künftig Klarnamen.' -ForegroundColor Green
        Write-Host 'Hinweis: Bereits erzeugte Reports ändern sich rückwirkend nicht;'
        Write-Host 'die nächste Erfassung (spätestens am Folgetag) enthält Klarnamen.'
    }
}
else {
    Write-Host 'Berichte zeigen bereits Klarnamen — nichts zu tun.' -ForegroundColor Green
}
