/* M365 Speicher-Dashboard — Frontend-Logik */
'use strict';

const $ = (sel) => document.querySelector(sel);

let state = {
  users: [],          // aufbereitete Benutzerliste
  history: [],
  status: null,
  sortKey: 'totalBytes',
  sortDir: -1,        // -1 = absteigend
  chart: null,
};

// ---------- Formatierung ----------
const fmtBytes = (b) => {
  if (b == null || isNaN(b)) return '–';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let i = 0, v = Number(b);
  while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
  return v.toLocaleString('de-CH', { maximumFractionDigits: v >= 100 ? 0 : 1 }) + ' ' + units[i];
};
const fmtDate = (iso) => {
  if (!iso) return '–';
  const d = new Date(iso);
  return d.toLocaleDateString('de-CH', { day: '2-digit', month: '2-digit', year: 'numeric' });
};

// ---------- Daten laden ----------
async function loadData() {
  const resp = await fetch('/api/data');
  if (!resp.ok) throw new Error('API-Fehler ' + resp.status);
  const data = await resp.json();
  state.status = data.status;
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
    };
  });
  render();
}

// ---------- Rendering ----------
function render() {
  const st = state.status || {};
  $('#bannerSetup').classList.toggle('hidden', !!st.configured);
  $('#bannerConcealed').classList.toggle('hidden', !st.concealed);
  $('#metaInfo').innerHTML = [
    st.demoMode ? '<strong>Demo-Modus</strong>' : '',
    st.snapshotDate ? 'Snapshot: ' + fmtDate(st.snapshotDate) : '',
    st.lastCollection ? 'Erfasst: ' + fmtDate(st.lastCollection) : '',
  ].filter(Boolean).join(' · ');

  renderTiles();
  renderChart();
  renderTable();
}

function renderTiles() {
  const mbx = state.users.reduce((s, u) => s + u.mailboxBytes, 0);
  const od = state.users.reduce((s, u) => s + u.onedriveBytes, 0);
  const css = getComputedStyle(document.documentElement);
  const cMbx = css.getPropertyValue('--series-mailbox').trim();
  const cOd = css.getPropertyValue('--series-onedrive').trim();

  // Zuwachs seit erstem Snapshot
  let growth = '';
  if (state.history.length >= 2) {
    const first = state.history[0], last = state.history[state.history.length - 1];
    const delta = (Number(last.mailbox_total) + Number(last.onedrive_total)) -
                  (Number(first.mailbox_total) + Number(first.onedrive_total));
    growth = (delta >= 0 ? '+' : '−') + fmtBytes(Math.abs(delta)) + ' seit ' + fmtDate(first.snapshot_date);
  }

  $('#tiles').innerHTML = `
    <div class="tile">
      <div class="label">Gesamtbelegung</div>
      <div class="value">${fmtBytes(mbx + od)}</div>
      <div class="sub">${growth || '&nbsp;'}</div>
    </div>
    <div class="tile">
      <div class="label"><span class="dot" style="background:${cMbx}"></span>Mailboxen</div>
      <div class="value">${fmtBytes(mbx)}</div>
      <div class="sub">&nbsp;</div>
    </div>
    <div class="tile">
      <div class="label"><span class="dot" style="background:${cOd}"></span>OneDrive</div>
      <div class="value">${fmtBytes(od)}</div>
      <div class="sub">&nbsp;</div>
    </div>
    <div class="tile">
      <div class="label">Benutzer</div>
      <div class="value">${state.users.length}</div>
      <div class="sub">&nbsp;</div>
    </div>`;
}

function renderChart() {
  const css = getComputedStyle(document.documentElement);
  const cMbx = css.getPropertyValue('--series-mailbox').trim();
  const cOd = css.getPropertyValue('--series-onedrive').trim();
  const cGrid = css.getPropertyValue('--grid').trim();
  const cMuted = css.getPropertyValue('--text-muted').trim();
  const cInk = css.getPropertyValue('--text-primary').trim();
  const cSurface = css.getPropertyValue('--surface-1').trim();

  const labels = state.history.map((h) => fmtDate(h.snapshot_date));
  const dsMbx = state.history.map((h) => Number(h.mailbox_total));
  const dsOd = state.history.map((h) => Number(h.onedrive_total));

  if (state.chart) state.chart.destroy();
  state.chart = new Chart($('#historyChart'), {
    type: 'line',
    data: {
      labels,
      datasets: [
        { label: 'Mailboxen', data: dsMbx, borderColor: cMbx, backgroundColor: cMbx,
          borderWidth: 2, pointRadius: 3, pointHoverRadius: 5, tension: 0.15 },
        { label: 'OneDrive', data: dsOd, borderColor: cOd, backgroundColor: cOd,
          borderWidth: 2, pointRadius: 3, pointHoverRadius: 5, tension: 0.15 },
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
            footer: (items) => 'Gesamt: ' + fmtBytes(items.reduce((s, i) => s + i.parsed.y, 0)),
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
    ${flag ? `<span class="flag" title="Quota fast erreicht">${flag}</span>` : ''}
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

  const k = state.sortKey, dir = state.sortDir;
  list.sort((a, b) => {
    const va = a[k], vb = b[k];
    if (typeof va === 'string') return va.localeCompare(vb, 'de') * dir;
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
      <td class="num">${fmtBytes(u.mailboxBytes)}</td>
      <td>${quotaCell(u.mailboxPct, cMbx)}</td>
      <td class="num">${fmtBytes(u.onedriveBytes)}</td>
      <td>${quotaCell(u.onedrivePct, cOd)}</td>
      <td class="num"><strong>${fmtBytes(u.totalBytes)}</strong></td>
    </tr>`).join('');

  $('#tableFoot').textContent = `${list.length} von ${state.users.length} Benutzern`;

  document.querySelectorAll('#userTable th').forEach((th) => {
    const arrow = th.querySelector('.arrow');
    arrow.textContent = th.dataset.key === state.sortKey ? (state.sortDir < 0 ? ' ▼' : ' ▲') : '';
  });
}

// ---------- Einstellungen ----------
async function openSettings() {
  const s = await (await fetch('/api/settings')).json();
  $('#inTenant').value = s.tenantId || '';
  $('#inClient').value = s.clientId || '';
  $('#inSecret').value = '';
  $('#inSecret').placeholder = s.secretSet ? '••••••••  (gespeichert — leer lassen zum Beibehalten)' : '';
  $('#inDemo').checked = !!s.demoMode;
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
  };
  const secret = $('#inSecret').value;
  if (secret) body.clientSecret = secret;
  const resp = await fetch('/api/settings', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
  });
  const r = await resp.json();
  if (!resp.ok) { setMsg(r.error || 'Speichern fehlgeschlagen', true); return false; }
  return true;
}

async function testConnection() {
  setMsg('Teste Verbindung …');
  if (!(await saveSettings())) return;
  try {
    const resp = await fetch('/api/test', { method: 'POST' });
    const r = await resp.json();
    setMsg(resp.ok ? r.message : r.error, !resp.ok);
  } catch (e) { setMsg('Fehler: ' + e.message, true); }
}

async function collectNow() {
  const btn = $('#btnCollect');
  btn.disabled = true;
  btn.innerHTML = '<span class="spin">◌</span> Erfasse …';
  try {
    const resp = await fetch('/api/collect', { method: 'POST' });
    const r = await resp.json();
    if (!resp.ok) throw new Error(r.error || 'Erfassung fehlgeschlagen');
    await loadData();
  } catch (e) {
    alert(e.message);
  } finally {
    btn.disabled = false;
    btn.textContent = 'Jetzt erfassen';
  }
}

// ---------- Events ----------
$('#btnSettings').addEventListener('click', openSettings);
$('#linkSettings').addEventListener('click', (e) => { e.preventDefault(); openSettings(); });
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
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', render);

loadData().catch((e) => {
  $('#tiles').innerHTML = `<div class="banner critical">Daten konnten nicht geladen werden: ${e.message}</div>`;
});
