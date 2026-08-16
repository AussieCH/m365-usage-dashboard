/* M365 Speicher-Dashboard — Frontend-Logik */
'use strict';

const $ = (sel) => document.querySelector(sel);

// ---------- Übersetzungen ----------
const I18N = {
  de: {
    title: 'M365 Speicher-Dashboard',
    btnCollect: 'Jetzt erfassen',
    btnCollectTitle: 'Daten jetzt vom Tenant abrufen',
    btnCollecting: 'Erfasse …',
    btnSettings: '⚙︎ Einstellungen',
    tabUsers: 'Benutzer',
    bannerSetupHtml: '<strong>Noch nicht konfiguriert.</strong> Bitte in den <a href="#" id="linkSettings">Einstellungen</a> Tenant-ID, Client-ID und Client-Secret hinterlegen — oder den Demo-Modus aktivieren.',
    bannerLicense: 'Lizenzinformationen fehlen.',
    bannerLicenseHint: 'Der App fehlen vermutlich die Berechtigungen User.Read.All und Organization.Read.All. Technische Details: ',
    bannerSites: 'Website-Namen fehlen.',
    bannerSitesHint: 'Der App fehlt vermutlich die Berechtigung Sites.Read.All. Technische Details: ',
    bannerConcealedHtml: '<strong>Benutzernamen sind pseudonymisiert.</strong> Im Microsoft 365 Admin Center unter <em>Einstellungen → Organisationseinstellungen → Berichte</em> die Option «Verborgene Benutzer-, Gruppen- und Websitenamen in allen Berichten anzeigen» aktivieren, danach neu erfassen.',
    metaDemo: 'Demo-Modus',
    metaSnapshot: 'Snapshot:',
    metaCollected: 'Erfasst:',
    chartTitle: 'Belegung über Zeit',
    usersCardTitle: 'Benutzer',
    siteChartTitle: 'SharePoint-Belegung über Zeit',
    sitesCardTitle: 'Websites',
    searchPlaceholder: 'Suchen (Name oder Benutzername) …',
    filterAll: 'Alle Benutzer',
    filterMbx80: 'Mailbox > 80 % der Quota',
    filterOd80: 'OneDrive > 80 % der Quota',
    filterTop10: 'Top 10 Gesamtbelegung',
    filterShared: 'Freigegebene Postfächer',
    thUser: 'Benutzer', thLicense: 'Lizenz', thMailbox: 'Mailbox', thMailboxQuota: 'Mailbox-Quota',
    thOneDrive: 'OneDrive', thOneDriveQuota: 'OneDrive-Quota', thTotal: 'Gesamt',
    siteSearchPlaceholder: 'Suchen (Name, URL oder Besitzer) …',
    sFilterAll: 'Alle Websites',
    sFilterInactive: 'Inaktiv > 90 Tage',
    sFilterTop10: 'Top 10 Speicher',
    sFilterTeam: 'Teamwebsites',
    sFilterComm: 'Kommunikationswebsites',
    thSite: 'Website', thType: 'Typ', thOwner: 'Besitzer', thStorage: 'Speicher', thFiles: 'Dateien',
    thActiveFiles: 'Aktive Dateien', thPageViews: 'Seitenaufrufe', thLastActivity: 'Letzte Aktivität',
    tileTotal: 'Gesamtbelegung (Mail + OneDrive + SharePoint)',
    tileMailboxes: 'Mailboxen', tileUsers: 'Benutzer',
    tileSpStorage: 'SharePoint-Belegung', tileSites: 'Websites', tileFiles: 'Dateien',
    tileInactive: 'Inaktiv > 90 Tage', tileInactiveSub: 'Kandidaten für Archivierung',
    since: 'seit',
    sharedMailboxes: 'Freigegebene Postfächer',
    noLicense: 'Ohne Lizenz',
    chipShared: 'Freigegeben',
    chipInactive: 'Inaktiv',
    quotaFlagTitle: 'Quota fast erreicht',
    chartMailboxes: 'Mailboxen',
    tooltipTotal: 'Gesamt: ',
    usersFoot: '{n} von {total} Benutzern',
    sitesFoot: '{n} von {total} Websites',
    today: 'heute', yesterday: 'gestern', daysAgo: 'vor {d} Tagen',
    systemSitePrefix: 'Systemwebsite: ',
    dlgTitle: 'Einstellungen',
    lblTenant: 'Tenant-ID (Verzeichnis-ID)',
    lblClient: 'Client-ID (Anwendungs-ID)',
    lblSecret: 'Client-Secret',
    lblLanguage: 'Sprache / Language',
    lblDemo: 'Demo-Modus (Beispieldaten statt Tenant-Abruf)',
    secretSetPlaceholder: '••••••••  (gespeichert — leer lassen zum Beibehalten)',
    btnTest: 'Verbindung testen', btnClose: 'Schliessen', btnSave: 'Speichern',
    msgTesting: 'Teste Verbindung …',
    msgSaveFailed: 'Speichern fehlgeschlagen',
    msgError: 'Fehler: ',
    collectFailed: 'Erfassung fehlgeschlagen',
    loadFailed: 'Daten konnten nicht geladen werden: ',
    templates: {
      'GROUP#0': 'Teamwebsite',
      'SITEPAGEPUBLISHING#0': 'Kommunikation',
      'STS#0': 'Teamwebsite (klassisch)',
      'STS#3': 'Teamwebsite (klassisch)',
      'TEAMCHANNEL#0': 'Teams-Kanal',
      'TEAMCHANNEL#1': 'Teams-Kanal',
      'APPCATALOG#0': 'App-Katalog',
      'SRCHCEN#0': 'Suchcenter',
      'SPSMSITEHOST#0': 'System',
      'POINTPUBLISHINGHUB#0': 'System',
      'POINTPUBLISHINGPERSONAL#0': 'System',
      'EHS#1': 'System',
    },
  },
  en: {
    title: 'M365 Storage Dashboard',
    btnCollect: 'Collect now',
    btnCollectTitle: 'Fetch data from the tenant now',
    btnCollecting: 'Collecting …',
    btnSettings: '⚙︎ Settings',
    tabUsers: 'Users',
    bannerSetupHtml: '<strong>Not configured yet.</strong> Please enter tenant ID, client ID and client secret in the <a href="#" id="linkSettings">settings</a> — or enable demo mode.',
    bannerLicense: 'License information missing.',
    bannerLicenseHint: 'The app is probably missing the User.Read.All and Organization.Read.All permissions. Technical details: ',
    bannerSites: 'Site names missing.',
    bannerSitesHint: 'The app is probably missing the Sites.Read.All permission. Technical details: ',
    bannerConcealedHtml: '<strong>User names are pseudonymized.</strong> In the Microsoft 365 admin center under <em>Settings → Org settings → Reports</em>, enable the display of concealed user, group and site names in all reports, then collect again.',
    metaDemo: 'Demo mode',
    metaSnapshot: 'Snapshot:',
    metaCollected: 'Collected:',
    chartTitle: 'Storage over time',
    usersCardTitle: 'Users',
    siteChartTitle: 'SharePoint storage over time',
    sitesCardTitle: 'Sites',
    searchPlaceholder: 'Search (name or username) …',
    filterAll: 'All users',
    filterMbx80: 'Mailbox > 80 % of quota',
    filterOd80: 'OneDrive > 80 % of quota',
    filterTop10: 'Top 10 total storage',
    filterShared: 'Shared mailboxes',
    thUser: 'User', thLicense: 'License', thMailbox: 'Mailbox', thMailboxQuota: 'Mailbox quota',
    thOneDrive: 'OneDrive', thOneDriveQuota: 'OneDrive quota', thTotal: 'Total',
    siteSearchPlaceholder: 'Search (name, URL or owner) …',
    sFilterAll: 'All sites',
    sFilterInactive: 'Inactive > 90 days',
    sFilterTop10: 'Top 10 storage',
    sFilterTeam: 'Team sites',
    sFilterComm: 'Communication sites',
    thSite: 'Site', thType: 'Type', thOwner: 'Owner', thStorage: 'Storage', thFiles: 'Files',
    thActiveFiles: 'Active files', thPageViews: 'Page views', thLastActivity: 'Last activity',
    tileTotal: 'Total storage (Mail + OneDrive + SharePoint)',
    tileMailboxes: 'Mailboxes', tileUsers: 'Users',
    tileSpStorage: 'SharePoint storage', tileSites: 'Sites', tileFiles: 'Files',
    tileInactive: 'Inactive > 90 days', tileInactiveSub: 'Archiving candidates',
    since: 'since',
    sharedMailboxes: 'Shared mailboxes',
    noLicense: 'No license',
    chipShared: 'Shared',
    chipInactive: 'Inactive',
    quotaFlagTitle: 'Quota almost reached',
    chartMailboxes: 'Mailboxes',
    tooltipTotal: 'Total: ',
    usersFoot: '{n} of {total} users',
    sitesFoot: '{n} of {total} sites',
    today: 'today', yesterday: 'yesterday', daysAgo: '{d} days ago',
    systemSitePrefix: 'System site: ',
    dlgTitle: 'Settings',
    lblTenant: 'Tenant ID (directory ID)',
    lblClient: 'Client ID (application ID)',
    lblSecret: 'Client secret',
    lblLanguage: 'Language / Sprache',
    lblDemo: 'Demo mode (sample data instead of tenant access)',
    secretSetPlaceholder: '••••••••  (saved — leave empty to keep)',
    btnTest: 'Test connection', btnClose: 'Close', btnSave: 'Save',
    msgTesting: 'Testing connection …',
    msgSaveFailed: 'Saving failed',
    msgError: 'Error: ',
    collectFailed: 'Collection failed',
    loadFailed: 'Failed to load data: ',
    templates: {
      'GROUP#0': 'Team site',
      'SITEPAGEPUBLISHING#0': 'Communication',
      'STS#0': 'Team site (classic)',
      'STS#3': 'Team site (classic)',
      'TEAMCHANNEL#0': 'Teams channel',
      'TEAMCHANNEL#1': 'Teams channel',
      'APPCATALOG#0': 'App catalog',
      'SRCHCEN#0': 'Search center',
      'SPSMSITEHOST#0': 'System',
      'POINTPUBLISHINGHUB#0': 'System',
      'POINTPUBLISHINGPERSONAL#0': 'System',
      'EHS#1': 'System',
    },
  },
};

let LANG = 'de';
const t = (k) => I18N[LANG]?.[k] ?? I18N.de[k] ?? k;
const locale = () => (LANG === 'de' ? 'de-CH' : 'en-GB');
const fmtInt = (n) => Number(n).toLocaleString(locale());

// Statische Texte (data-i18n-Attribute) auf die aktive Sprache setzen
function applyStaticTexts() {
  document.documentElement.lang = LANG;
  document.title = t('title');
  document.querySelectorAll('[data-i18n]').forEach((el) => {
    // Kopfzellen enthalten den Sortierpfeil — nur den Textknoten ersetzen
    if (el.firstChild && el.firstChild.nodeType === Node.TEXT_NODE && el.children.length) {
      el.firstChild.nodeValue = t(el.dataset.i18n);
    } else {
      el.textContent = t(el.dataset.i18n);
    }
  });
  document.querySelectorAll('[data-i18n-ph]').forEach((el) => { el.placeholder = t(el.dataset.i18nPh); });
  document.querySelectorAll('[data-i18n-title]').forEach((el) => { el.title = t(el.dataset.i18nTitle); });
  document.querySelectorAll('[data-i18n-html]').forEach((el) => { el.innerHTML = t(el.dataset.i18nHtml); });
}

let state = {
  users: [],          // aufbereitete Benutzerliste
  history: [],
  sites: [],
  siteHistory: [],
  status: null,
  sortKey: 'totalBytes',
  sortDir: -1,        // -1 = absteigend
  siteSortKey: 'storageBytes',
  siteSortDir: -1,
  chart: null,
  siteChart: null,
  siteViewDirty: true, // Sites-Tab bei nächster Aktivierung neu rendern
};

// ---------- Formatierung ----------
const fmtBytes = (b) => {
  if (b == null || isNaN(b)) return '–';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let i = 0, v = Number(b);
  while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
  return v.toLocaleString(locale(), { maximumFractionDigits: v >= 100 ? 0 : 1 }) + ' ' + units[i];
};
const fmtDate = (iso) => {
  if (!iso) return '–';
  const d = new Date(iso);
  return d.toLocaleDateString(locale(), { day: '2-digit', month: '2-digit', year: 'numeric' });
};

// Sprachabhängige Site-Felder (Name-Fallback, Typ-Label) neu ableiten
function deriveSiteLabels() {
  for (const s of state.sites) {
    s.templateLabel = t('templates')[s.template] || s.template || '–';
    s.name = s.rawName || s.urlName ||
      (s.template ? t('systemSitePrefix') + s.templateLabel : s.siteId);
  }
}

// ---------- Daten laden ----------
async function loadData() {
  const resp = await fetch('/api/data');
  if (!resp.ok) throw new Error('API error ' + resp.status);
  const data = await resp.json();
  state.status = data.status;

  const lang = data.status?.language;
  if ((lang === 'de' || lang === 'en') && lang !== LANG) {
    LANG = lang;
    applyStaticTexts();
  }

  state.history = data.history || [];
  state.users = (data.users || []).map((u) => {
    const mailboxBytes = Number(u.mailbox_bytes) || 0;
    const onedriveBytes = Number(u.onedrive_bytes) || 0;
    const mbq = Number(u.mailbox_quota_bytes) || 0;
    const odq = Number(u.onedrive_quota_bytes) || 0;
    return {
      upn: u.upn,
      displayName: u.display_name || u.upn,
      mailboxBytes, onedriveBytes,
      mailboxQuota: mbq, onedriveQuota: odq,
      mailboxPct: mbq > 0 ? (mailboxBytes / mbq) * 100 : null,
      onedrivePct: odq > 0 ? (onedriveBytes / odq) * 100 : null,
      totalBytes: mailboxBytes + onedriveBytes,
      licenses: u.licenses || '',
      isShared: Number(u.is_shared) === 1,
    };
  });
  state.siteHistory = data.siteHistory || [];
  state.sites = (data.sites || []).map((s) => {
    const url = s.url || '';
    const urlName = url ? decodeURIComponent(url.replace(/\/$/, '').split('/').pop() || url) : '';
    let daysInactive = null;
    if (s.last_activity) {
      const d = new Date(s.last_activity);
      if (!isNaN(d)) daysInactive = Math.max(0, Math.floor((Date.now() - d.getTime()) / 86400000));
    }
    return {
      siteId: s.site_id, url,
      rawName: s.name || '',   // echter Anzeigename aus Graph (Systemwebsites: leer)
      urlName,
      owner: s.owner || '',
      template: s.template || '',
      lastActivity: s.last_activity || '',
      daysInactive,
      files: Number(s.files) || 0,
      activeFiles: Number(s.active_files) || 0,
      pageViews: Number(s.page_views) || 0,
      storageBytes: Number(s.storage_bytes) || 0,
      quotaBytes: Number(s.quota_bytes) || 0,
    };
  });
  deriveSiteLabels();
  state.siteViewDirty = true;
  render();
}

// ---------- Rendering ----------
function render() {
  const st = state.status || {};
  $('#bannerSetup').classList.toggle('hidden', !!st.configured);
  $('#bannerConcealed').classList.toggle('hidden', !st.concealed);
  $('#bannerLicense').classList.toggle('hidden', !st.licenseWarning);
  $('#bannerLicenseText').textContent = st.licenseWarning ? t('bannerLicenseHint') + st.licenseWarning : '';
  $('#bannerSites').classList.toggle('hidden', !st.siteWarning);
  $('#bannerSitesText').textContent = st.siteWarning ? t('bannerSitesHint') + st.siteWarning : '';
  $('#metaInfo').innerHTML = [
    st.demoMode ? `<strong>${t('metaDemo')}</strong>` : '',
    st.snapshotDate ? t('metaSnapshot') + ' ' + fmtDate(st.snapshotDate) : '',
    st.lastCollection ? t('metaCollected') + ' ' + fmtDate(st.lastCollection) : '',
  ].filter(Boolean).join(' · ');

  renderTiles();
  renderChart();
  renderTable();
  // Sites-Tab nur rendern, wenn er sichtbar ist (Chart braucht sichtbare Canvas)
  if (!$('#viewSites').classList.contains('hidden')) renderSiteView();
}

function renderSiteView() {
  renderSiteTiles();
  renderSiteChart();
  renderSiteTable();
  state.siteViewDirty = false;
}

// Historien (Benutzer + Sites) über das Snapshot-Datum zusammenführen
function mergedHistory() {
  const mbx = {}, od = {}, sp = {};
  for (const h of state.history) {
    mbx[h.snapshot_date] = Number(h.mailbox_total);
    od[h.snapshot_date] = Number(h.onedrive_total);
  }
  for (const h of state.siteHistory) sp[h.snapshot_date] = Number(h.storage_total);
  const dates = [...new Set([...Object.keys(mbx), ...Object.keys(sp)])].sort();
  return { dates, mbx, od, sp };
}

function renderTiles() {
  const mbxT = state.users.reduce((s, u) => s + u.mailboxBytes, 0);
  const odT = state.users.reduce((s, u) => s + u.onedriveBytes, 0);
  const spT = state.sites.reduce((s, x) => s + x.storageBytes, 0);
  const css = getComputedStyle(document.documentElement);
  const cMbx = css.getPropertyValue('--series-mailbox').trim();
  const cOd = css.getPropertyValue('--series-onedrive').trim();
  const cSp = css.getPropertyValue('--series-sharepoint').trim();

  // Zuwachs seit erstem Snapshot (Mail + OneDrive + SharePoint)
  const m = mergedHistory();
  let growth = '';
  if (m.dates.length >= 2) {
    const total = (d) => (m.mbx[d] || 0) + (m.od[d] || 0) + (m.sp[d] || 0);
    const first = m.dates[0], last = m.dates[m.dates.length - 1];
    const delta = total(last) - total(first);
    growth = (delta >= 0 ? '+' : '−') + fmtBytes(Math.abs(delta)) + ' ' + t('since') + ' ' + fmtDate(first);
  }

  $('#tiles').innerHTML = `
    <div class="tile">
      <div class="label">${t('tileTotal')}</div>
      <div class="value">${fmtBytes(mbxT + odT + spT)}</div>
      <div class="sub"><span class="dot" style="background:${cMbx}"></span> ${t('tileMailboxes')}: ${fmtBytes(mbxT)}</div>
      <div class="sub"><span class="dot" style="background:${cOd}"></span> OneDrive: ${fmtBytes(odT)}</div>
      <div class="sub"><span class="dot" style="background:${cSp}"></span> SharePoint: ${fmtBytes(spT)}</div>
      <div class="sub">${growth || '&nbsp;'}</div>
    </div>
    <div class="tile">
      <div class="label">${t('tileUsers')}</div>
      <div class="value">${state.users.length}</div>
      ${licenseBreakdown()}
    </div>`;
}

function licenseBreakdown() {
  // Benutzer pro Lizenztyp zählen; freigegebene Postfächer als eigene Kategorie
  const counts = new Map();
  for (const u of state.users) {
    const key = u.isShared ? t('sharedMailboxes') : (u.licenses || t('noLicense'));
    counts.set(key, (counts.get(key) || 0) + 1);
  }
  if (counts.size === 1 && counts.has(t('noLicense'))) return '<div class="sub">&nbsp;</div>';
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([name, n]) => `<div class="sub">${n} × ${name}</div>`)
    .join('');
}

function renderChart() {
  const css = getComputedStyle(document.documentElement);
  const cMbx = css.getPropertyValue('--series-mailbox').trim();
  const cOd = css.getPropertyValue('--series-onedrive').trim();
  const cSp = css.getPropertyValue('--series-sharepoint').trim();
  const cGrid = css.getPropertyValue('--grid').trim();
  const cMuted = css.getPropertyValue('--text-muted').trim();
  const cInk = css.getPropertyValue('--text-primary').trim();
  const cSurface = css.getPropertyValue('--surface-1').trim();

  const m = mergedHistory();
  const labels = m.dates.map((d) => fmtDate(d));
  const pick = (map) => m.dates.map((d) => map[d] ?? null);
  const lineOpts = { borderWidth: 2, pointRadius: 3, pointHoverRadius: 5, tension: 0.15, spanGaps: true };

  if (state.chart) state.chart.destroy();
  state.chart = new Chart($('#historyChart'), {
    type: 'line',
    data: {
      labels,
      datasets: [
        { label: t('chartMailboxes'), data: pick(m.mbx), borderColor: cMbx, backgroundColor: cMbx, ...lineOpts },
        { label: 'OneDrive', data: pick(m.od), borderColor: cOd, backgroundColor: cOd, ...lineOpts },
        { label: 'SharePoint', data: pick(m.sp), borderColor: cSp, backgroundColor: cSp, ...lineOpts },
      ],
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      interaction: { mode: 'index', intersect: false },
      plugins: {
        legend: { labels: { color: cInk, usePointStyle: true, pointStyle: 'circle', boxWidth: 8 } },
        tooltip: {
          backgroundColor: cSurface, titleColor: cInk, bodyColor: cInk,
          borderColor: cGrid, borderWidth: 1,
          callbacks: {
            label: (ctx) => ` ${ctx.dataset.label}: ${fmtBytes(ctx.parsed.y)}`,
            footer: (items) => t('tooltipTotal') + fmtBytes(items.reduce((s, i) => s + i.parsed.y, 0)),
          },
        },
      },
      scales: {
        x: { grid: { color: cGrid }, ticks: { color: cMuted } },
        y: {
          grid: { color: cGrid },
          ticks: { color: cMuted, callback: (v) => fmtBytes(v) },
          beginAtZero: true,
        },
      },
    },
  });
}

function quotaCell(pct, seriesColor) {
  if (pct == null) return '<span class="quota"><span class="pct">–</span></span>';
  const cls = pct >= 95 ? 'crit' : pct >= 80 ? 'warn' : '';
  const flag = pct >= 95 ? '⛔' : pct >= 80 ? '⚠️' : '';
  const width = Math.min(100, pct).toFixed(0);
  return `<span class="quota ${cls}">
    <span class="bar"><i style="width:${width}%;background:${seriesColor}"></i></span>
    <span class="pct">${pct.toFixed(0)} %</span>
    ${flag ? `<span class="flag" title="${t('quotaFlagTitle')}">${flag}</span>` : ''}
  </span>`;
}

function filteredUsers() {
  const q = $('#searchBox').value.trim().toLowerCase();
  const mode = $('#filterSelect').value;
  let list = state.users.filter((u) =>
    !q || u.displayName.toLowerCase().includes(q) || u.upn.toLowerCase().includes(q));
  if (mode === 'mbx80') list = list.filter((u) => u.mailboxPct != null && u.mailboxPct > 80);
  if (mode === 'od80') list = list.filter((u) => u.onedrivePct != null && u.onedrivePct > 80);
  if (mode === 'top10') list = [...list].sort((a, b) => b.totalBytes - a.totalBytes).slice(0, 10);
  if (mode === 'shared') list = list.filter((u) => u.isShared);

  const k = state.sortKey, dir = state.sortDir;
  list.sort((a, b) => {
    const va = a[k], vb = b[k];
    if (typeof va === 'string') return va.localeCompare(vb, LANG) * dir;
    return ((va ?? -1) - (vb ?? -1)) * dir;
  });
  return list;
}

function renderTable() {
  const css = getComputedStyle(document.documentElement);
  const cMbx = css.getPropertyValue('--series-mailbox').trim();
  const cOd = css.getPropertyValue('--series-onedrive').trim();
  const list = filteredUsers();

  $('#userTable tbody').innerHTML = list.map((u) => `
    <tr>
      <td>${u.displayName}<br><span class="upn">${u.upn}</span></td>
      <td class="lic">${u.isShared ? `<span class="chip">${t('chipShared')}</span>` : (u.licenses || '<span class="upn">–</span>')}</td>
      <td class="num">${fmtBytes(u.mailboxBytes)}</td>
      <td>${quotaCell(u.mailboxPct, cMbx)}</td>
      <td class="num">${fmtBytes(u.onedriveBytes)}</td>
      <td>${quotaCell(u.onedrivePct, cOd)}</td>
      <td class="num"><strong>${fmtBytes(u.totalBytes)}</strong></td>
    </tr>`).join('');

  $('#tableFoot').textContent = t('usersFoot')
    .replace('{n}', list.length).replace('{total}', state.users.length);

  document.querySelectorAll('#userTable th').forEach((th) => {
    const arrow = th.querySelector('.arrow');
    arrow.textContent = th.dataset.key === state.sortKey ? (state.sortDir < 0 ? ' ▼' : ' ▲') : '';
  });
}

// ---------- SharePoint-Ansicht ----------
function renderSiteTiles() {
  const total = state.sites.reduce((s, x) => s + x.storageBytes, 0);
  const files = state.sites.reduce((s, x) => s + x.files, 0);
  const inactive = state.sites.filter((x) => x.daysInactive != null && x.daysInactive > 90).length;

  let growth = '';
  if (state.siteHistory.length >= 2) {
    const first = state.siteHistory[0], last = state.siteHistory[state.siteHistory.length - 1];
    const delta = Number(last.storage_total) - Number(first.storage_total);
    growth = (delta >= 0 ? '+' : '−') + fmtBytes(Math.abs(delta)) + ' ' + t('since') + ' ' + fmtDate(first.snapshot_date);
  }

  $('#siteTiles').innerHTML = `
    <div class="tile">
      <div class="label">${t('tileSpStorage')}</div>
      <div class="value">${fmtBytes(total)}</div>
      <div class="sub">${growth || '&nbsp;'}</div>
    </div>
    <div class="tile">
      <div class="label">${t('tileSites')}</div>
      <div class="value">${state.sites.length}</div>
      <div class="sub">&nbsp;</div>
    </div>
    <div class="tile">
      <div class="label">${t('tileFiles')}</div>
      <div class="value">${fmtInt(files)}</div>
      <div class="sub">&nbsp;</div>
    </div>
    <div class="tile">
      <div class="label">${t('tileInactive')}</div>
      <div class="value">${inactive}</div>
      <div class="sub">${inactive ? t('tileInactiveSub') : '&nbsp;'}</div>
    </div>`;
}

function renderSiteChart() {
  const css = getComputedStyle(document.documentElement);
  const cSeries = css.getPropertyValue('--series-sharepoint').trim(); // SharePoint = Slot 3, wie im Übersichts-Chart
  const cGrid = css.getPropertyValue('--grid').trim();
  const cMuted = css.getPropertyValue('--text-muted').trim();
  const cInk = css.getPropertyValue('--text-primary').trim();
  const cSurface = css.getPropertyValue('--surface-1').trim();

  const labels = state.siteHistory.map((h) => fmtDate(h.snapshot_date));
  const data = state.siteHistory.map((h) => Number(h.storage_total));

  if (state.siteChart) state.siteChart.destroy();
  state.siteChart = new Chart($('#siteChart'), {
    type: 'line',
    data: {
      labels,
      datasets: [
        { label: 'SharePoint', data, borderColor: cSeries, backgroundColor: cSeries,
          borderWidth: 2, pointRadius: 3, pointHoverRadius: 5, tension: 0.15 },
      ],
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      interaction: { mode: 'index', intersect: false },
      plugins: {
        legend: { display: false }, // eine Serie — der Kartentitel benennt sie
        tooltip: {
          backgroundColor: cSurface, titleColor: cInk, bodyColor: cInk,
          borderColor: cGrid, borderWidth: 1,
          callbacks: { label: (ctx) => ' ' + fmtBytes(ctx.parsed.y) },
        },
      },
      scales: {
        x: { grid: { color: cGrid }, ticks: { color: cMuted } },
        y: {
          grid: { color: cGrid },
          ticks: { color: cMuted, callback: (v) => fmtBytes(v) },
          beginAtZero: true,
        },
      },
    },
  });
}

function filteredSites() {
  const q = $('#siteSearchBox').value.trim().toLowerCase();
  const mode = $('#siteFilterSelect').value;
  let list = state.sites.filter((s) =>
    !q || s.name.toLowerCase().includes(q) || s.url.toLowerCase().includes(q) ||
    s.owner.toLowerCase().includes(q));
  if (mode === 'inactive') list = list.filter((s) => s.daysInactive != null && s.daysInactive > 90);
  if (mode === 'top10') list = [...list].sort((a, b) => b.storageBytes - a.storageBytes).slice(0, 10);
  if (mode === 'team') list = list.filter((s) => s.template.startsWith('GROUP') || s.template.startsWith('STS') || s.template.startsWith('TEAMCHANNEL'));
  if (mode === 'comm') list = list.filter((s) => s.template.startsWith('SITEPAGEPUBLISHING'));

  const k = state.siteSortKey, dir = state.siteSortDir;
  list.sort((a, b) => {
    const va = a[k], vb = b[k];
    if (typeof va === 'string') return va.localeCompare(vb, LANG) * dir;
    return ((va ?? -1) - (vb ?? -1)) * dir;
  });
  return list;
}

function activityCell(s) {
  if (s.daysInactive == null) return '<span class="upn">–</span>';
  const warn = s.daysInactive > 90;
  const label = s.daysInactive === 0 ? t('today')
    : s.daysInactive === 1 ? t('yesterday')
    : t('daysAgo').replace('{d}', s.daysInactive);
  return `${warn ? `<span class="chip">${t('chipInactive')}</span> ` : ''}<span title="${fmtDate(s.lastActivity)}">${label}</span>`;
}

function sitePath(url) {
  // Nur den Pfad anzeigen (/sites/Alan); die volle URL bleibt im Tooltip
  try { return new URL(url).pathname || '/'; } catch { return url; }
}

function renderSiteTable() {
  const list = filteredSites();
  $('#siteTable tbody').innerHTML = list.map((s) => `
    <tr>
      <td>${s.name}<span class="upn" title="${s.url || s.siteId}">${s.url ? sitePath(s.url) : s.siteId}</span></td>
      <td class="lic">${s.templateLabel}</td>
      <td class="lic">${s.owner || '–'}</td>
      <td class="num"><strong>${fmtBytes(s.storageBytes)}</strong></td>
      <td class="num">${fmtInt(s.files)}</td>
      <td class="num">${fmtInt(s.activeFiles)}</td>
      <td class="num">${fmtInt(s.pageViews)}</td>
      <td class="num">${activityCell(s)}</td>
    </tr>`).join('');

  $('#siteTableFoot').textContent = t('sitesFoot')
    .replace('{n}', list.length).replace('{total}', state.sites.length);

  document.querySelectorAll('#siteTable th').forEach((th) => {
    const arrow = th.querySelector('.arrow');
    arrow.textContent = th.dataset.key === state.siteSortKey ? (state.siteSortDir < 0 ? ' ▼' : ' ▲') : '';
  });
}

function switchTab(tab) {
  const users = tab === 'users';
  $('#viewUsers').classList.toggle('hidden', !users);
  $('#viewSites').classList.toggle('hidden', users);
  $('#tabUsers').classList.toggle('active', users);
  $('#tabSites').classList.toggle('active', !users);
  $('#tabUsers').setAttribute('aria-selected', users);
  $('#tabSites').setAttribute('aria-selected', !users);
  history.replaceState(null, '', users ? location.pathname : '#sharepoint');
  if (!users && state.siteViewDirty) renderSiteView();
}

// ---------- Einstellungen ----------
async function openSettings() {
  const s = await (await fetch('/api/settings')).json();
  $('#inTenant').value = s.tenantId || '';
  $('#inClient').value = s.clientId || '';
  $('#inSecret').value = '';
  $('#inSecret').placeholder = s.secretSet ? t('secretSetPlaceholder') : '';
  $('#inDemo').checked = !!s.demoMode;
  $('#inLang').value = s.language === 'en' ? 'en' : 'de';
  setMsg('');
  $('#settingsDialog').showModal();
}

function setMsg(text, isError) {
  const el = $('#settingsMsg');
  el.textContent = text;
  el.className = 'msg ' + (isError ? 'err' : 'ok');
}

async function saveSettings() {
  const body = {
    tenantId: $('#inTenant').value.trim(),
    clientId: $('#inClient').value.trim(),
    demoMode: $('#inDemo').checked,
    language: $('#inLang').value,
  };
  const secret = $('#inSecret').value;
  if (secret) body.clientSecret = secret;
  const resp = await fetch('/api/settings', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
  });
  const r = await resp.json();
  if (!resp.ok) { setMsg(r.error || t('msgSaveFailed'), true); return false; }
  // Sprachwechsel sofort anwenden
  if (body.language !== LANG) {
    LANG = body.language;
    applyStaticTexts();
    deriveSiteLabels();
  }
  return true;
}

async function testConnection() {
  setMsg(t('msgTesting'));
  if (!(await saveSettings())) return;
  try {
    const resp = await fetch('/api/test', { method: 'POST' });
    const r = await resp.json();
    setMsg(resp.ok ? r.message : r.error, !resp.ok);
  } catch (e) { setMsg(t('msgError') + e.message, true); }
}

async function collectNow() {
  const btn = $('#btnCollect');
  btn.disabled = true;
  btn.innerHTML = `<span class="spin">◌</span> ${t('btnCollecting')}`;
  try {
    const resp = await fetch('/api/collect', { method: 'POST' });
    const r = await resp.json();
    if (!resp.ok) throw new Error(r.error || t('collectFailed'));
    await loadData();
  } catch (e) {
    alert(e.message);
  } finally {
    btn.disabled = false;
    btn.textContent = t('btnCollect');
  }
}

// ---------- Events ----------
$('#btnSettings').addEventListener('click', openSettings);
// Delegiert, weil der Setup-Banner (inkl. Link) beim Sprachwechsel neu gerendert wird
document.addEventListener('click', (e) => {
  if (e.target.id === 'linkSettings') { e.preventDefault(); openSettings(); }
});
$('#btnClose').addEventListener('click', () => $('#settingsDialog').close());
$('#btnTest').addEventListener('click', testConnection);
$('#settingsForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  if (await saveSettings()) { $('#settingsDialog').close(); loadData(); }
});
$('#btnCollect').addEventListener('click', collectNow);
$('#searchBox').addEventListener('input', renderTable);
$('#filterSelect').addEventListener('change', renderTable);
document.querySelectorAll('#userTable th').forEach((th) => {
  th.addEventListener('click', () => {
    const key = th.dataset.key;
    if (state.sortKey === key) state.sortDir *= -1;
    else { state.sortKey = key; state.sortDir = key === 'displayName' ? 1 : -1; }
    renderTable();
  });
});
$('#tabUsers').addEventListener('click', () => switchTab('users'));
$('#tabSites').addEventListener('click', () => switchTab('sites'));
$('#siteSearchBox').addEventListener('input', renderSiteTable);
$('#siteFilterSelect').addEventListener('change', renderSiteTable);
document.querySelectorAll('#siteTable th').forEach((th) => {
  th.addEventListener('click', () => {
    const key = th.dataset.key;
    if (state.siteSortKey === key) state.siteSortDir *= -1;
    else { state.siteSortKey = key; state.siteSortDir = ['name', 'templateLabel', 'owner'].includes(key) ? 1 : -1; }
    renderSiteTable();
  });
});
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', render);
if (location.hash === '#sharepoint') switchTab('sites');  // Deep-Link auf den SharePoint-Reiter

loadData().catch((e) => {
  $('#tiles').innerHTML = `<div class="banner critical">${t('loadFailed')}${e.message}</div>`;
});
