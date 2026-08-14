# App.psm1 — verbindet Settings, Graph und Storage zur eigentlichen Datenerfassung.

function Invoke-UsageCollection {
    <#
      Führt eine Datenerfassung durch und speichert den Snapshot.
      Im Demo-Modus werden zusätzlich 12 zurückliegende Wochen-Snapshots erzeugt,
      damit das Zuwachs-Diagramm sofort etwas zeigt.
    #>
    $settings = Get-AppSettings

    if ($settings.demoMode) {
        $today = Get-Date
        for ($w = 12; $w -ge 0; $w--) {
            $snap = Get-DemoSnapshot -Seed 42
            $factor = 1.0 - ($w * 0.025)   # ~2.5 % Wachstum pro Woche simulieren
            $users = $snap.users | ForEach-Object {
                $u = $_.PSObject.Copy()
                $u.mailboxBytes  = [long]($u.mailboxBytes * $factor)
                $u.onedriveBytes = [long]($u.onedriveBytes * $factor)
                $u
            }
            $date = $today.AddDays(-7 * $w).ToString('yyyy-MM-dd')
            Save-Snapshot -SnapshotDate $date -Users $users
        }
        Set-MetaValue -Key 'concealed' -Value 'false'
        return [pscustomobject]@{ ok = $true; users = $snap.users.Count; date = $today.ToString('yyyy-MM-dd'); demo = $true }
    }

    $secret = Unprotect-ClientSecret -Settings $settings
    if (-not ($settings.tenantId -and $settings.clientId -and $secret)) {
        throw 'Tenant nicht konfiguriert. Bitte zuerst Tenant-ID, Client-ID und Client-Secret hinterlegen.'
    }

    $snap = Get-UsageSnapshot -TenantId $settings.tenantId -ClientId $settings.clientId -ClientSecret $secret
    if ($snap.users.Count -eq 0) {
        throw 'Report war leer — keine Benutzerdaten erhalten.'
    }
    Save-Snapshot -SnapshotDate $snap.reportDate -Users $snap.users
    Set-MetaValue -Key 'concealed' -Value ([string]$snap.concealed).ToLower()

    [pscustomobject]@{ ok = $true; users = $snap.users.Count; date = $snap.reportDate; concealed = $snap.concealed }
}

function Get-DashboardData {
    <# Liefert alle Daten für das Dashboard in einem Rutsch. #>
    $settings = Get-AppSettings
    $secretSet = [bool]$settings.clientSecretEnc
    [pscustomobject]@{
        status = [pscustomobject]@{
            configured     = [bool]($settings.tenantId -and $settings.clientId -and $secretSet) -or $settings.demoMode
            demoMode       = [bool]$settings.demoMode
            lastCollection = (Get-MetaValue -Key 'lastCollection')
            snapshotDate   = (Get-LatestSnapshotDate)
            concealed      = ((Get-MetaValue -Key 'concealed') -eq 'true')
        }
        history = @(Get-History)
        users   = @(Get-LatestUsers)
    }
}

Export-ModuleMember -Function Invoke-UsageCollection, Get-DashboardData
