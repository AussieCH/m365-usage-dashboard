# App.psm1 — verbindet Settings, Graph und Storage zur eigentlichen Datenerfassung.

function Invoke-UsageCollection {
    <#
      Führt eine Datenerfassung durch und speichert den Snapshot.
      Im Demo-Modus werden zusätzlich 12 zurückliegende Wochen-Snapshots erzeugt,
      damit das Zuwachs-Diagramm sofort etwas zeigt.
    #>
    $settings = Get-AppSettings
    Initialize-Database   # idempotent — stellt das Schema sicher, auch wenn die DB im Betrieb gelöscht wurde

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
            $sites = $snap.sites | ForEach-Object {
                $s = $_.PSObject.Copy()
                $s.storageBytes = [long]($s.storageBytes * $factor)
                $s
            }
            $date = $today.AddDays(-7 * $w).ToString('yyyy-MM-dd')
            Save-Snapshot -SnapshotDate $date -Users $users
            Save-SiteSnapshot -SnapshotDate $date -Sites $sites
        }
        Set-MetaValue -Key 'concealed' -Value 'false'
        Set-MetaValue -Key 'licenseWarning' -Value ''
        Set-MetaValue -Key 'siteWarning' -Value ''
        return [pscustomobject]@{ ok = $true; users = $snap.users.Count; date = $today.ToString('yyyy-MM-dd'); demo = $true }
    }

    $secret = Unprotect-ClientSecret -Settings $settings
    if (-not ($settings.tenantId -and $settings.clientId -and $secret)) {
        throw (Get-Text 'notConfigured')
    }

    $snap = Get-UsageSnapshot -TenantId $settings.tenantId -ClientId $settings.clientId -ClientSecret $secret
    if ($snap.users.Count -eq 0) {
        throw (Get-Text 'emptyReport')
    }

    # Schlägt der Namens-Abruf fehl (z. B. 403 während Consent-Propagation), bereits
    # bekannte Namen/URLs aus dem letzten Snapshot übernehmen statt sie zu löschen.
    if ($snap.siteWarning) {
        $prev = @{}
        foreach ($p in (Get-LatestSites)) {
            if ($p.name -or $p.url) { $prev[$p.site_id] = $p }
        }
        foreach ($s in $snap.sites) {
            $old = $prev[$s.siteId]
            if ($old) {
                if (-not $s.name -and $old.name) { $s.name = [string]$old.name }
                if (-not $s.url -and $old.url) { $s.url = [string]$old.url }
            }
        }
    }
    Save-Snapshot -SnapshotDate $snap.reportDate -Users $snap.users
    Save-SiteSnapshot -SnapshotDate $snap.reportDate -Sites $snap.sites
    Set-MetaValue -Key 'concealed' -Value ([string]$snap.concealed).ToLower()
    Set-MetaValue -Key 'licenseWarning' -Value ([string]$snap.licenseWarning)
    Set-MetaValue -Key 'siteWarning' -Value ([string]$snap.siteWarning)

    [pscustomobject]@{ ok = $true; users = $snap.users.Count; sites = $snap.sites.Count; date = $snap.reportDate; concealed = $snap.concealed }
}

function Get-DashboardData {
    <# Liefert alle Daten für das Dashboard in einem Rutsch. #>
    $settings = Get-AppSettings
    Initialize-Database   # idempotent, siehe Invoke-UsageCollection
    $secretSet = [bool]$settings.clientSecretEnc
    [pscustomobject]@{
        status = [pscustomobject]@{
            configured     = [bool]($settings.tenantId -and $settings.clientId -and $secretSet) -or $settings.demoMode
            demoMode       = [bool]$settings.demoMode
            lastCollection = (Get-MetaValue -Key 'lastCollection')
            snapshotDate   = (Get-LatestSnapshotDate)
            concealed      = ((Get-MetaValue -Key 'concealed') -eq 'true')
            language       = [string]$settings.language
            licenseWarning = [string](Get-MetaValue -Key 'licenseWarning')
            siteWarning    = [string](Get-MetaValue -Key 'siteWarning')
        }
        history     = @(Get-History)
        users       = @(Get-LatestUsers)
        siteHistory = @(Get-SiteHistory)
        sites       = @(Get-LatestSites)
    }
}

Export-ModuleMember -Function Invoke-UsageCollection, Get-DashboardData
