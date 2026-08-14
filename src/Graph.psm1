# Graph.psm1 — Microsoft Graph: Token holen und Usage-Reports (CSV) abrufen.
# Benötigte App-Berechtigung (Application): Reports.Read.All mit Admin-Consent.

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
            }
        }
        $u = $users[$key]
        $u.onedriveBytes      = [long]($row.'Storage Used (Byte)'      | ForEach-Object { if ($_) { $_ } else { 0 } })
        $u.onedriveQuotaBytes = [long]($row.'Storage Allocated (Byte)' | ForEach-Object { if ($_) { $_ } else { 0 } })
        $u.onedriveFiles      = [long]($row.'File Count'               | ForEach-Object { if ($_) { $_ } else { 0 } })
        if (-not $u.displayName) { $u.displayName = $row.'Owner Display Name' }
    }

    # Pseudonymisierte Reports erkennen: UPNs sind dann Hashes ohne '@'
    $upns = @($users.Values | ForEach-Object { $_.upn })
    $concealed = $upns.Count -gt 0 -and (@($upns | Where-Object { $_ -notmatch '@' }).Count -gt ($upns.Count / 2))

    $refreshDate = ($mbx | Select-Object -First 1).'Report Refresh Date'
    if (-not $refreshDate) { $refreshDate = (Get-Date).ToString('yyyy-MM-dd') }

    [pscustomobject]@{
        reportDate = $refreshDate
        concealed  = $concealed
        users      = @($users.Values | ForEach-Object { [pscustomobject]$_ })
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
    $users = foreach ($n in $names) {
        $upn = ($n.ToLower() -replace 'ä','ae' -replace 'ö','oe' -replace 'ü','ue' -replace ' ','.') + '@demo.example'
        [pscustomobject]@{
            upn = $upn; displayName = $n
            mailboxBytes       = [long]($rand.NextDouble() * 40GB + 200MB)
            mailboxQuotaBytes  = 50GB
            mailboxItems       = [long]($rand.Next(2000, 90000))
            onedriveBytes      = [long]($rand.NextDouble() * 300GB + 1GB)
            onedriveQuotaBytes = 1TB
            onedriveFiles      = [long]($rand.Next(500, 40000))
        }
    }
    [pscustomobject]@{
        reportDate = (Get-Date).ToString('yyyy-MM-dd')
        concealed  = $false
        users      = @($users)
    }
}

Export-ModuleMember -Function Get-GraphToken, Get-GraphReportCsv, Get-UsageSnapshot, Get-DemoSnapshot
