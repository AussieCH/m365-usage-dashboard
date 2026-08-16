# Graph.psm1 — Microsoft Graph: Token holen und Usage-Reports (CSV) abrufen.
# Benötigte App-Berechtigungen (Application, mit Admin-Consent):
#   Reports.Read.All                       — Usage-Reports (Pflicht)
#   User.Read.All + Organization.Read.All  — Lizenzen & freigegebene Postfächer (optional)

# Gängige SKU-Teilenummern → lesbare Produktnamen (Rest fällt auf die Teilenummer zurück)
$script:SkuNames = @{
    'O365_BUSINESS_ESSENTIALS' = 'Microsoft 365 Business Basic'
    'O365_BUSINESS_PREMIUM'    = 'Microsoft 365 Business Standard'
    'SPB'                      = 'Microsoft 365 Business Premium'
    'O365_BUSINESS'            = 'Microsoft 365 Apps for Business'
    'OFFICESUBSCRIPTION'       = 'Microsoft 365 Apps for Enterprise'
    'SPE_E3'                   = 'Microsoft 365 E3'
    'SPE_E5'                   = 'Microsoft 365 E5'
    'SPE_F1'                   = 'Microsoft 365 F3'
    'M365_F1'                  = 'Microsoft 365 F1'
    'STANDARDPACK'             = 'Office 365 E1'
    'ENTERPRISEPACK'           = 'Office 365 E3'
    'ENTERPRISEPREMIUM'        = 'Office 365 E5'
    'EXCHANGESTANDARD'         = 'Exchange Online (Plan 1)'
    'EXCHANGEENTERPRISE'       = 'Exchange Online (Plan 2)'
    'EXCHANGEDESKLESS'         = 'Exchange Online Kiosk'
}

# Kostenlose Zusatz-SKUs, die die Lizenz-Aufschlüsselung nur verrauschen würden
$script:IgnoredSkus = @(
    'FLOW_FREE'                # Power Automate Free
    'TEAMS_EXPLORATORY'
    'TEAMS_COMMERCIAL_TRIAL'
    'POWER_BI_STANDARD'        # Power BI (kostenlos)
    'POWERAPPS_VIRAL'
    'CCIBOTS_PRIVPREV_VIRAL'
    'RIGHTSMANAGEMENT_ADHOC'
    'WINDOWS_STORE'
)

function Get-GraphToken {
    param(
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$ClientSecret
    )
    $body = @{
        grant_type    = 'client_credentials'
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = 'https://graph.microsoft.com/.default'
    }
    $resp = Invoke-RestMethod -Method Post `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -Body $body -ErrorAction Stop
    $resp.access_token
}

function Get-GraphReportCsv {
    param(
        [Parameter(Mandatory)][string]$Token,
        [Parameter(Mandatory)][string]$ReportName   # z.B. getMailboxUsageDetail
    )
    $uri = "https://graph.microsoft.com/v1.0/reports/$ReportName(period='D7')"
    # Graph antwortet mit 302 auf eine CSV-Download-URL; Invoke-WebRequest folgt automatisch.
    $resp = Invoke-WebRequest -Uri $uri -Headers @{ Authorization = "Bearer $Token" } -ErrorAction Stop
    $text = [Text.Encoding]::UTF8.GetString($resp.Content)
    # BOM entfernen, dann CSV parsen
    $text.TrimStart([char]0xFEFF) | ConvertFrom-Csv
}

function Get-GraphJsonPaged {
    param(
        [Parameter(Mandatory)][string]$Token,
        [Parameter(Mandatory)][string]$Uri
    )
    $items = @()
    while ($Uri) {
        $r = Invoke-RestMethod -Uri $Uri -Headers @{ Authorization = "Bearer $Token" } -ErrorAction Stop
        $items += $r.value
        $Uri = $r.'@odata.nextLink'
    }
    $items
}

function Get-UsageSnapshot {
    <#
      Ruft Mailbox- und OneDrive-Report ab und liefert pro Benutzer einen
      zusammengeführten Datensatz plus Metadaten (Report-Datum, Pseudonymisierung).
    #>
    param(
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$ClientSecret
    )
    $token = Get-GraphToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

    $mbx = Get-GraphReportCsv -Token $token -ReportName 'getMailboxUsageDetail'
    $od  = Get-GraphReportCsv -Token $token -ReportName 'getOneDriveUsageAccountDetail'
    $sp  = Get-GraphReportCsv -Token $token -ReportName 'getSharePointSiteUsageDetail'

    $users = @{}
    foreach ($row in $mbx) {
        if ($row.'Is Deleted' -eq 'True') { continue }
        $upn = $row.'User Principal Name'
        if (-not $upn) { continue }
        $users[$upn.ToLowerInvariant()] = [ordered]@{
            upn                = $upn
            displayName        = $row.'Display Name'
            mailboxBytes       = [long]($row.'Storage Used (Byte)' | ForEach-Object { if ($_) { $_ } else { 0 } })
            mailboxQuotaBytes  = [long]($row.'Prohibit Send/Receive Quota (Byte)' | ForEach-Object { if ($_) { $_ } else { 0 } })
            mailboxItems       = [long]($row.'Item Count' | ForEach-Object { if ($_) { $_ } else { 0 } })
            onedriveBytes      = 0L
            onedriveQuotaBytes = 0L
            onedriveFiles      = 0L
            licenses           = ''
            isShared           = 0
            hasMailbox         = $true
        }
    }
    foreach ($row in $od) {
        if ($row.'Is Deleted' -eq 'True') { continue }
        $upn = $row.'Owner Principal Name'
        if (-not $upn) { continue }
        $key = $upn.ToLowerInvariant()
        if (-not $users.Contains($key)) {
            $users[$key] = [ordered]@{
                upn = $upn; displayName = $row.'Owner Display Name'
                mailboxBytes = 0L; mailboxQuotaBytes = 0L; mailboxItems = 0L
                onedriveBytes = 0L; onedriveQuotaBytes = 0L; onedriveFiles = 0L
                licenses = ''; isShared = 0; hasMailbox = $false
            }
        }
        $u = $users[$key]
        $u.onedriveBytes      = [long]($row.'Storage Used (Byte)'      | ForEach-Object { if ($_) { $_ } else { 0 } })
        $u.onedriveQuotaBytes = [long]($row.'Storage Allocated (Byte)' | ForEach-Object { if ($_) { $_ } else { 0 } })
        $u.onedriveFiles      = [long]($row.'File Count'               | ForEach-Object { if ($_) { $_ } else { 0 } })
        if (-not $u.displayName) { $u.displayName = $row.'Owner Display Name' }
    }

    # SharePoint-Sites aufbereiten
    $sites = foreach ($row in $sp) {
        if ($row.'Is Deleted' -eq 'True') { continue }
        if (-not $row.'Site Id') { continue }
        [pscustomobject]@{
            siteId       = $row.'Site Id'
            url          = $row.'Site URL'
            name         = ''
            owner        = $row.'Owner Display Name'
            template     = $row.'Root Web Template'
            lastActivity = $row.'Last Activity Date'
            files        = [long]($row.'File Count'          | ForEach-Object { if ($_) { $_ } else { 0 } })
            activeFiles  = [long]($row.'Active File Count'   | ForEach-Object { if ($_) { $_ } else { 0 } })
            pageViews    = [long]($row.'Page View Count'     | ForEach-Object { if ($_) { $_ } else { 0 } })
            storageBytes = [long]($row.'Storage Used (Byte)' | ForEach-Object { if ($_) { $_ } else { 0 } })
            quotaBytes   = [long]($row.'Storage Allocated (Byte)' | ForEach-Object { if ($_) { $_ } else { 0 } })
        }
    }

    # Website-Namen und -URLs ergänzen (optional — braucht Sites.Read.All).
    # Hintergrund: Der Usage-Report liefert die Site-URL in vielen Tenants nicht mehr.
    $siteWarning = ''
    try {
        $allSites = Get-GraphJsonPaged -Token $token `
            -Uri 'https://graph.microsoft.com/v1.0/sites/getAllSites?$select=id,displayName,webUrl'
        # Site-ID im Report = mittlerer GUID-Teil der zusammengesetzten Graph-Site-ID
        $siteMap = @{}
        foreach ($s in $allSites) {
            $parts = ([string]$s.id).Split(',')
            if ($parts.Count -ge 2) { $siteMap[$parts[1].ToLowerInvariant()] = $s }
        }
        foreach ($site in $sites) {
            $info = $siteMap[$site.siteId.ToLowerInvariant()]
            if ($info) {
                if ($info.displayName) { $site.name = [string]$info.displayName }
                if (-not $site.url -and $info.webUrl) { $site.url = [string]$info.webUrl }
            }
        }
    }
    catch {
        # Sprachneutral speichern — der erklärende Satz kommt übersetzt aus dem Frontend
        $siteWarning = [string]$_.Exception.Message
    }

    # Lizenzen und freigegebene Postfächer ergänzen (optional — braucht
    # User.Read.All + Organization.Read.All; ohne diese Rechte läuft der Rest weiter)
    $licenseWarning = ''
    try {
        $skus = Get-GraphJsonPaged -Token $token -Uri 'https://graph.microsoft.com/v1.0/subscribedSkus'
        $skuMap = @{}
        foreach ($s in $skus) {
            if ($script:IgnoredSkus -contains $s.skuPartNumber) { continue }
            $name = $script:SkuNames[$s.skuPartNumber]
            $skuMap[$s.skuId] = if ($name) { $name } else { $s.skuPartNumber }
        }
        $adUsers = Get-GraphJsonPaged -Token $token `
            -Uri 'https://graph.microsoft.com/v1.0/users?$select=userPrincipalName,accountEnabled,assignedLicenses&$top=999'
        foreach ($au in $adUsers) {
            if (-not $au.userPrincipalName) { continue }
            $key = $au.userPrincipalName.ToLowerInvariant()
            if (-not $users.Contains($key)) { continue }
            $u = $users[$key]
            $lic = @($au.assignedLicenses | ForEach-Object { $skuMap[$_.skuId] } | Where-Object { $_ }) | Sort-Object -Unique
            if ($lic.Count -gt 0) {
                $u.licenses = $lic -join ' + '
            }
            elseif (-not $au.accountEnabled -and $u.hasMailbox) {
                # Kein Lizenz + Konto deaktiviert + Postfach vorhanden = freigegebenes Postfach
                $u.isShared = 1
            }
        }
    }
    catch {
        # Sprachneutral speichern — der erklärende Satz kommt übersetzt aus dem Frontend
        $licenseWarning = [string]$_.Exception.Message
    }

    # Pseudonymisierte Reports erkennen: UPNs sind dann Hashes ohne '@'
    $upns = @($users.Values | ForEach-Object { $_.upn })
    $concealed = $upns.Count -gt 0 -and (@($upns | Where-Object { $_ -notmatch '@' }).Count -gt ($upns.Count / 2))

    $refreshDate = ($mbx | Select-Object -First 1).'Report Refresh Date'
    if (-not $refreshDate) { $refreshDate = (Get-Date).ToString('yyyy-MM-dd') }

    [pscustomobject]@{
        reportDate     = $refreshDate
        concealed      = $concealed
        licenseWarning = $licenseWarning
        siteWarning    = $siteWarning
        users          = @($users.Values | ForEach-Object { [pscustomobject]$_ })
        sites          = @($sites)
    }
}

function Get-DemoSnapshot {
    <# Erzeugt Demodaten (25 Benutzer, reproduzierbar) für Tests ohne Tenant. #>
    param([int]$Seed = 42)
    $rand = [Random]::new($Seed)
    $names = 'Anna Meier','Beat Huber','Carla Steiner','Daniel Frey','Elena Widmer','Fabian Koch',
             'Gina Brunner','Hans Keller','Iris Baumann','Jonas Graf','Karin Suter','Luca Moser',
             'Mara Fischer','Nico Weber','Olivia Gerber','Pascal Roth','Regula Zbinden','Simon Wyss',
             'Tanja Hofer','Urs Schmid','Vera Lang','Walter Egli','Yvonne Marti','Reto Bühler','Sandra Vogel'
    $i = 0
    $users = foreach ($n in $names) {
        $upn = ($n.ToLower() -replace 'ä','ae' -replace 'ö','oe' -replace 'ü','ue' -replace ' ','.') + '@demo.example'
        $lic = if ($i -lt 14) { 'Microsoft 365 Business Standard' }
               elseif ($i -lt 20) { 'Microsoft 365 Business Premium' }
               else { 'Microsoft 365 E3' }
        $i++
        [pscustomobject]@{
            upn = $upn; displayName = $n
            mailboxBytes       = [long]($rand.NextDouble() * 40GB + 200MB)
            mailboxQuotaBytes  = 50GB
            mailboxItems       = [long]($rand.Next(2000, 90000))
            onedriveBytes      = [long]($rand.NextDouble() * 300GB + 1GB)
            onedriveQuotaBytes = 1TB
            onedriveFiles      = [long]($rand.Next(500, 40000))
            licenses           = $lic
            isShared           = 0
        }
    }
    $shared = foreach ($n in 'Info', 'Support', 'Buchhaltung') {
        [pscustomobject]@{
            upn = $n.ToLower() + '@demo.example'; displayName = $n
            mailboxBytes       = [long]($rand.NextDouble() * 15GB + 500MB)
            mailboxQuotaBytes  = 50GB
            mailboxItems       = [long]($rand.Next(5000, 60000))
            onedriveBytes      = 0L
            onedriveQuotaBytes = 0L
            onedriveFiles      = 0L
            licenses           = ''
            isShared           = 1
        }
    }
    $siteDefs = @(
        @{ n = 'Intranet';   t = 'SITEPAGEPUBLISHING#0'; gb = 18;  act = 2 },
        @{ n = 'Projekte';   t = 'GROUP#0';              gb = 260; act = 1 },
        @{ n = 'Vertrieb';   t = 'GROUP#0';              gb = 95;  act = 3 },
        @{ n = 'Marketing';  t = 'GROUP#0';              gb = 140; act = 5 },
        @{ n = 'IT';         t = 'GROUP#0';              gb = 75;  act = 2 },
        @{ n = 'GL';         t = 'GROUP#0';              gb = 22;  act = 8 },
        @{ n = 'Qualitaet';  t = 'GROUP#0';              gb = 48;  act = 12 },
        @{ n = 'Events';     t = 'GROUP#0';              gb = 34;  act = 60 },
        @{ n = 'Archiv';     t = 'STS#3';                gb = 410; act = 210 },
        @{ n = 'Altprojekte'; t = 'STS#3';               gb = 180; act = 130 }
    )
    $sites = foreach ($sd in $siteDefs) {
        [pscustomobject]@{
            siteId       = 'demo-site-' + $sd.n.ToLower()
            url          = 'https://demo.sharepoint.com/sites/' + $sd.n
            name         = $sd.n
            owner        = $names[$rand.Next(0, $names.Count)]
            template     = $sd.t
            lastActivity = (Get-Date).AddDays(-$sd.act).ToString('yyyy-MM-dd')
            files        = [long]($rand.Next(800, 60000))
            activeFiles  = [long]($rand.Next(0, 900))
            pageViews    = [long]($rand.Next(5, 4000))
            storageBytes = [long]($sd.gb * 1GB + $rand.NextDouble() * 5GB)
            quotaBytes   = 25TB
        }
    }
    [pscustomobject]@{
        reportDate     = (Get-Date).ToString('yyyy-MM-dd')
        concealed      = $false
        licenseWarning = ''
        siteWarning    = ''
        users          = @($users) + @($shared)
        sites          = @($sites)
    }
}

Export-ModuleMember -Function Get-GraphToken, Get-GraphReportCsv, Get-GraphJsonPaged, Get-UsageSnapshot, Get-DemoSnapshot
