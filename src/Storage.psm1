# Storage.psm1 — SQLite-Persistenz (Datei data/usage.db).
# Backend: unter Windows PSSQLite (bündelt System.Data.SQLite);
# auf macOS/Linux (Entwicklung) das systemeigene sqlite3-CLI mit JSON-Ausgabe.

$script:DbPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'data/usage.db'
$script:UseCli = -not $IsWindows
if (-not $script:UseCli) { Import-Module PSSQLite }

function ConvertTo-SqlLiteral {
    param($Value)
    if ($null -eq $Value) { return 'NULL' }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) {
        return $Value.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }
    "'" + ([string]$Value -replace "'", "''") + "'"
}

function Invoke-Db {
    param([Parameter(Mandatory)][string]$Query, [hashtable]$Params)
    if ($script:UseCli) {
        $sql = $Query
        if ($Params) {
            # Längere Namen zuerst ersetzen, damit @mb nicht in @mbq greift
            foreach ($k in ($Params.Keys | Sort-Object Length -Descending)) {
                $sql = $sql -replace "@$k\b", (ConvertTo-SqlLiteral $Params[$k])
            }
        }
        $out = $sql | sqlite3 -json $script:DbPath 2>&1
        if ($LASTEXITCODE -ne 0) { throw "sqlite3-Fehler: $out" }
        $text = ($out | Out-String).Trim()
        if ($text) { return ($text | ConvertFrom-Json) }  # Array wird von der Pipeline enumeriert
        return @()
    }
    Invoke-SqliteQuery -DataSource $script:DbPath -Query $Query -SqlParameters $Params
}

function Initialize-Database {
    $dir = Split-Path $script:DbPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    Invoke-Db -Query @'
CREATE TABLE IF NOT EXISTS snapshots (
    snapshot_date        TEXT NOT NULL,
    upn                  TEXT NOT NULL,
    display_name         TEXT,
    mailbox_bytes        INTEGER NOT NULL DEFAULT 0,
    mailbox_quota_bytes  INTEGER NOT NULL DEFAULT 0,
    mailbox_items        INTEGER NOT NULL DEFAULT 0,
    onedrive_bytes       INTEGER NOT NULL DEFAULT 0,
    onedrive_quota_bytes INTEGER NOT NULL DEFAULT 0,
    onedrive_files       INTEGER NOT NULL DEFAULT 0,
    licenses             TEXT NOT NULL DEFAULT '',
    is_shared            INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (snapshot_date, upn)
);
CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);
'@ | Out-Null

    # Migration älterer Datenbanken ohne Lizenzspalten
    $cols = @(Invoke-Db -Query 'PRAGMA table_info(snapshots)') | ForEach-Object { $_.name }
    if ($cols -notcontains 'licenses') {
        Invoke-Db -Query "ALTER TABLE snapshots ADD COLUMN licenses TEXT NOT NULL DEFAULT ''" | Out-Null
    }
    if ($cols -notcontains 'is_shared') {
        Invoke-Db -Query 'ALTER TABLE snapshots ADD COLUMN is_shared INTEGER NOT NULL DEFAULT 0' | Out-Null
    }
}

function Save-Snapshot {
    param(
        [Parameter(Mandatory)][string]$SnapshotDate,
        [Parameter(Mandatory)][object[]]$Users
    )
    $insert = @'
INSERT OR REPLACE INTO snapshots
    (snapshot_date, upn, display_name, mailbox_bytes, mailbox_quota_bytes, mailbox_items,
     onedrive_bytes, onedrive_quota_bytes, onedrive_files, licenses, is_shared)
VALUES (@date, @upn, @name, @mb, @mbq, @mbi, @od, @odq, @odf, @lic, @sh)
'@
    if ($script:UseCli) {
        # Alle Inserts als ein Skript in einer Transaktion ausführen
        $sb = [Text.StringBuilder]::new()
        [void]$sb.AppendLine('BEGIN TRANSACTION;')
        foreach ($u in $Users) {
            $vals = @(
                ConvertTo-SqlLiteral $SnapshotDate
                ConvertTo-SqlLiteral $u.upn
                ConvertTo-SqlLiteral $u.displayName
                ConvertTo-SqlLiteral ([long]$u.mailboxBytes)
                ConvertTo-SqlLiteral ([long]$u.mailboxQuotaBytes)
                ConvertTo-SqlLiteral ([long]$u.mailboxItems)
                ConvertTo-SqlLiteral ([long]$u.onedriveBytes)
                ConvertTo-SqlLiteral ([long]$u.onedriveQuotaBytes)
                ConvertTo-SqlLiteral ([long]$u.onedriveFiles)
                ConvertTo-SqlLiteral ([string]$u.licenses)
                ConvertTo-SqlLiteral ([int]$u.isShared)
            ) -join ', '
            [void]$sb.AppendLine(@"
INSERT OR REPLACE INTO snapshots
    (snapshot_date, upn, display_name, mailbox_bytes, mailbox_quota_bytes, mailbox_items,
     onedrive_bytes, onedrive_quota_bytes, onedrive_files, licenses, is_shared)
VALUES ($vals);
"@)
        }
        [void]$sb.AppendLine('COMMIT;')
        $out = $sb.ToString() | sqlite3 $script:DbPath 2>&1
        if ($LASTEXITCODE -ne 0) { throw "sqlite3-Fehler beim Speichern: $out" }
    }
    else {
        $conn = New-SQLiteConnection -DataSource $script:DbPath
        try {
            Invoke-SqliteQuery -SQLiteConnection $conn -Query 'BEGIN TRANSACTION'
            foreach ($u in $Users) {
                Invoke-SqliteQuery -SQLiteConnection $conn -Query $insert -SqlParameters @{
                    date = $SnapshotDate; upn = $u.upn; name = $u.displayName
                    mb = [long]$u.mailboxBytes; mbq = [long]$u.mailboxQuotaBytes; mbi = [long]$u.mailboxItems
                    od = [long]$u.onedriveBytes; odq = [long]$u.onedriveQuotaBytes; odf = [long]$u.onedriveFiles
                    lic = [string]$u.licenses; sh = [int]$u.isShared
                }
            }
            Invoke-SqliteQuery -SQLiteConnection $conn -Query 'COMMIT'
        }
        catch {
            Invoke-SqliteQuery -SQLiteConnection $conn -Query 'ROLLBACK'
            throw
        }
        finally {
            $conn.Close()
        }
    }
    Set-MetaValue -Key 'lastCollection' -Value (Get-Date).ToString('o')
}

function Get-LatestSnapshotDate {
    $r = Invoke-Db -Query 'SELECT MAX(snapshot_date) AS d FROM snapshots'
    ($r | Select-Object -First 1).d
}

function Get-LatestUsers {
    $d = Get-LatestSnapshotDate
    if (-not $d) { return @() }
    Invoke-Db -Query 'SELECT * FROM snapshots WHERE snapshot_date = @d ORDER BY upn' -Params @{ d = $d }
}

function Get-History {
    Invoke-Db -Query @'
SELECT snapshot_date,
       COUNT(*)            AS user_count,
       SUM(mailbox_bytes)  AS mailbox_total,
       SUM(onedrive_bytes) AS onedrive_total
FROM snapshots
GROUP BY snapshot_date
ORDER BY snapshot_date
'@
}

function Get-UserHistory {
    param([Parameter(Mandatory)][string]$Upn)
    Invoke-Db -Query 'SELECT snapshot_date, mailbox_bytes, onedrive_bytes FROM snapshots WHERE upn = @u ORDER BY snapshot_date' `
        -Params @{ u = $Upn }
}

function Set-MetaValue {
    param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    Invoke-Db -Query 'INSERT OR REPLACE INTO meta (key, value) VALUES (@k, @v)' -Params @{ k = $Key; v = $Value } | Out-Null
}

function Get-MetaValue {
    param([Parameter(Mandatory)][string]$Key)
    $r = Invoke-Db -Query 'SELECT value FROM meta WHERE key = @k' -Params @{ k = $Key }
    ($r | Select-Object -First 1).value
}

Export-ModuleMember -Function Initialize-Database, Save-Snapshot, Get-LatestSnapshotDate,
    Get-LatestUsers, Get-History, Get-UserHistory, Set-MetaValue, Get-MetaValue
