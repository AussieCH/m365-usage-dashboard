# M365 Speicher-Dashboard

OnePage-Web-App (PowerShell/Pode), die per Microsoft Graph die Postfachgrössen und
OneDrive-Belegung aller Benutzer eines Microsoft-365-Tenants ausliest, in einer
SQLite-Datenbank historisiert und als Dashboard darstellt:

- **Kacheln:** Gesamtbelegung, Mailboxen, OneDrive, Zuwachs seit Beginn sowie
  Benutzerzahl mit Aufschlüsselung pro Lizenztyp (inkl. freigegebener Postfächer)
- **Diagramm:** Belegung über Zeit (Mailbox / OneDrive getrennt, Tooltip mit Gesamt)
- **Benutzerliste:** sortierbar (Klick auf Spaltenkopf), Volltextsuche, Filter
  (Quota > 80 %, Top 10, freigegebene Postfächer), Lizenzspalte, Quota-Balken
  mit Warnschwellen (80 % / 95 %). Freigegebene Postfächer werden erkannt
  (Postfach vorhanden, Konto deaktiviert, keine Lizenz) und separat ausgewiesen
- **Einstellungen im UI:** Tenant-ID, Client-ID, Client-Secret (verschlüsselt
  gespeichert), Demo-Modus
- **SharePoint-Reiter:** alle Websites mit Speicherbelegung, Typ (Team/Kommunikation),
  Besitzer, Dateizahl, aktiven Dateien, Seitenaufrufen und letzter Aktivität;
  Inaktiv-Markierung (> 90 Tage) als Archivierungs-Kandidaten, eigener Zeitverlauf,
  Suche/Sortierung/Filter wie bei den Benutzern
- **Automatik:** eingebauter Wochen-Schedule (Standard: Montag 06:00) erfasst die
  Daten selbstständig, solange der Server läuft

## Voraussetzungen

- Windows Server oder PC (getestet auch unter macOS/Linux für Entwicklung)
- [PowerShell 7](https://aka.ms/powershell) (`winget install Microsoft.PowerShell`)
- Module: `Install-Module Pode, PSSQLite -Scope CurrentUser`
  (unter macOS/Linux wird statt PSSQLite automatisch das System-`sqlite3` benutzt)

## App-Registrierung im Kunden-Tenant (einmalig)

1. [Entra Admin Center](https://entra.microsoft.com) → **App-Registrierungen** →
   **Neue Registrierung** (Name z. B. „Speicher-Dashboard", nur dieser Tenant).
2. **API-Berechtigungen** → Hinzufügen → **Microsoft Graph** →
   **Anwendungsberechtigungen** → `Reports.Read.All`, `User.Read.All`,
   `Organization.Read.All` und `Sites.Read.All` → **Administratorzustimmung erteilen**.
   (`Reports.Read.All` ist Pflicht. `User.Read.All`/`Organization.Read.All` liefern
   Lizenztypen und die Erkennung freigegebener Postfächer; `Sites.Read.All` die
   Anzeigenamen der SharePoint-Websites, da der Usage-Report in vielen Tenants
   keine Site-URLs mehr enthält. Fehlen optionale Rechte, läuft die Erfassung
   trotzdem — das Dashboard zeigt dann einen Hinweis.)
3. **Zertifikate & Geheimnisse** → **Neuer geheimer Clientschlüssel** (Laufzeit z. B.
   24 Monate) → Wert sofort kopieren.
4. Notieren: **Verzeichnis-ID (Tenant)**, **Anwendungs-ID (Client)**, **Secret**.
5. **Wichtig — Klarnamen in Berichten:** Im
   [Microsoft 365 Admin Center](https://admin.microsoft.com) unter
   *Einstellungen → Organisationseinstellungen → Berichte* die Anzeige verborgener
   Benutzernamen **aktivieren** (Haken bei Pseudonymisierung entfernen), sonst
   liefern die Reports nur Hashes. Das Dashboard zeigt in dem Fall eine Warnung.

## Start

```bash
pwsh ./server.ps1
```

Dashboard: <http://localhost:8080> (Port in `settings.json` änderbar).
Beim ersten Start ⚙︎ **Einstellungen** öffnen, die drei Werte eintragen,
**Verbindung testen**, speichern, dann **Jetzt erfassen**.

Der **Demo-Modus** (Checkbox in den Einstellungen) erzeugt Beispieldaten mit
13 Wochen Historie — praktisch für Vorführungen ohne Tenant-Zugriff.

### Als Dauerdienst unter Windows

Am einfachsten als geplanter Task, der beim Systemstart läuft:

```powershell
Register-ScheduledTask -TaskName 'M365UsageDashboard' `
  -Action (New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument '-NoProfile -File C:\Apps\m365-usage-dashboard\server.ps1') `
  -Trigger (New-ScheduledTaskTrigger -AtStartup) `
  -Settings (New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)) `
  -User 'SYSTEM' -RunLevel Highest
```

Hinweis: Wird der Task unter einem anderen Konto ausgeführt als dem, mit dem das
Secret gespeichert wurde, muss das Secret einmal unter diesem Konto neu gespeichert
werden (DPAPI ist benutzergebunden).

## Datenhaltung

- `data/usage.db` — SQLite; Tabelle `snapshots` mit einem Datensatz pro Benutzer
  und Snapshot-Datum (Primärschlüssel `snapshot_date, upn`), Tabelle `site_snapshots`
  analog pro SharePoint-Site (`snapshot_date, site_id`), Tabelle `meta`.
- Erfassung überschreibt denselben Tag idempotent (`INSERT OR REPLACE`) —
  mehrfaches „Jetzt erfassen" erzeugt keine Duplikate.
- `settings.json` — Konfiguration; das Client-Secret ist unter Windows per DPAPI
  verschlüsselt und wird von der API nie zurückgegeben.
- Die Graph-Reports werden von Microsoft mit ca. 24–48 h Verzögerung aktualisiert;
  das Snapshot-Datum entspricht dem „Report Refresh Date" des Reports.

## Aufbau

| Datei | Zweck |
|---|---|
| `server.ps1` | Pode-Server: statisches UI, REST-API, Wochen-Schedule |
| `src/Graph.psm1` | Token (Client Credentials) + Reports-Abruf/-Merge, Demodaten |
| `src/Storage.psm1` | SQLite-Zugriff (PSSQLite bzw. sqlite3-CLI) |
| `src/Settings.psm1` | Einstellungen laden/speichern, Secret-Verschlüsselung |
| `src/App.psm1` | Erfassungslauf + Dashboard-Datenaggregation |
| `public/` | OnePage-Frontend (Vanilla JS + Chart.js, lokal gebündelt) |

### API

| Route | Zweck |
|---|---|
| `GET /api/data` | Status + Historie + aktuelle Benutzerliste |
| `GET/POST /api/settings` | Konfiguration lesen/schreiben (Secret nur schreibend) |
| `POST /api/test` | Verbindungstest (Token-Abruf) |
| `POST /api/collect` | Erfassung sofort ausführen |
