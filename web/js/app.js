'use strict';

// ─── State ───────────────────────────────────────────────────────────────────
const state = {
  page: 'overview',
  players: { page: 1, search: '' },
  logs:    { page: 1, filter: '', flagged: false },
  selectedPlayer: null,
  panelOpen: false,
  charFields: {},
  toast: { enabled: true, duration: 6000, messages: {} },
};

// ─── NUI bridge ──────────────────────────────────────────────────────────────
function postNUI(event, data = {}) {
  fetch(`https://mcSentinel/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
}

function requestData(query, params = {}) {
  postNUI('requestData', { query, params });
}

// ─── Router ──────────────────────────────────────────────────────────────────
function showPage(name) {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  const el = document.getElementById(`page-${name}`);
  if (el) el.classList.add('active');
  const nav = document.querySelector(`.nav-item[data-page="${name}"]`);
  if (nav) nav.classList.add('active');
  state.page = name;
}

// ─── Renderers ───────────────────────────────────────────────────────────────
function renderOverview(data) {
  const s = data.stats || {};
  setText('stat-online',  s.online_now    ?? 0);
  setText('stat-players', s.total_players ?? 0);
  setText('stat-alerts',  s.total_alerts  ?? 0);
  setText('stat-events',  s.total_events  ?? 0);

  const feed = document.getElementById('alert-feed');
  const alerts = data.alerts || [];
  if (alerts.length === 0) {
    feed.innerHTML = '<div class="feed-empty">No alerts — server is clean ✓</div>';
    return;
  }
  feed.innerHTML = alerts.map(a => `
    <div class="feed-row">
      <div class="feed-dot"></div>
      <div class="feed-type">${esc(a.type)}</div>
      <div class="feed-player" onclick="openPlayerDetail(${a.player_id})">${esc(a.player_name || '—')}</div>
      <div class="feed-time">${fmtDate(a.created_at)}</div>
    </div>
  `).join('');
}

function renderPlayers(rows) {
  const tbody = document.getElementById('player-table');
  if (!rows || rows.length === 0) {
    tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;color:var(--muted);padding:32px">No players found</td></tr>';
    return;
  }
  tbody.innerHTML = rows.map(p => {
    const onlineBadge = p.online
      ? `<span style="color:#4ade80;font-weight:600">● Online</span> <span class="mono" style="color:var(--muted);font-size:11px">[ID:${esc(p.server_id)}]</span>`
      : `<span style="color:var(--muted)">○ Offline</span>`;
    const charName = p.online && p.char_name ? `<div style="font-size:11px;color:var(--accent);margin-top:2px">${esc(p.char_name)}</div>` : '';
    return `
    <tr>
      <td>${onlineBadge}</td>
      <td style="font-weight:500">${esc(p.name)}${charName}</td>
      <td class="mono" style="font-size:11px">${esc(p.license)}</td>
      <td style="color:var(--muted)">${esc(p.ip || '—')}</td>
      <td>${p.alert_count > 0 ? `<span class="badge-red">${p.alert_count}</span>` : '<span style="color:var(--muted)">0</span>'}</td>
      <td><span class="link" onclick="openPlayerDetail(${p.id})">View →</span></td>
    </tr>`;
  }).join('');
}

function renderPlayerDetail(data) {
  state.selectedPlayer = data.player?.id;
  const p = data.player || {};
  const el = document.getElementById('player-detail-content');
  const alertCount = (data.events || []).filter(e => e.flagged).length;

  const chars = (data.characters || []).map(c => {
    let ci = {}, job = {}, money = {};
    try { ci    = JSON.parse(c.charinfo); } catch {}
    try { job   = JSON.parse(c.job);      } catch {}
    try { money = JSON.parse(c.money);    } catch {}
    const genderIcon = ci.gender === 0 ? '♂' : '♀';
    const jobLabel   = job.label || job.name || '—';
    const onlineChar = data.onlineCharId && data.onlineCharId === c.citizenid;
    const fmt = n => '$' + Number(n || 0).toLocaleString('en-US');
    const f = state.charFields;
    const meta = [
      f.citizenid !== false ? `<span>🆔 ${esc(c.citizenid)}</span>` : '',
      f.phone     !== false ? `<span>📞 ${esc(ci.phone || '—')}</span>` : '',
      f.birthdate !== false ? `<span>🎂 ${esc(ci.birthdate || '—')}</span>` : '',
      f.job       !== false ? `<span>💼 ${esc(jobLabel)}</span>` : '',
      f.cash      !== false ? `<span>💵 Cash: ${fmt(money.cash)}</span>` : '',
      f.bank      !== false ? `<span>🏦 Bank: ${fmt(money.bank)}</span>` : '',
      f.crypto    !== false && money.crypto ? `<span>🪙 Crypto: ${fmt(money.crypto)}</span>` : '',
    ].filter(Boolean).join('');
    return `
      <div class="char-card ${onlineChar ? 'char-online' : ''}">
        <div class="char-name">${genderIcon} ${esc(ci.firstname || '')} ${esc(ci.lastname || '')} ${onlineChar ? '<span class="char-online-badge">● Online</span>' : ''}</div>
        <div class="char-meta">${meta}</div>
      </div>`;
  }).join('');

  el.innerHTML = `
    <div class="detail-header">
      <div>
        <div class="detail-name">${esc(p.name)}</div>
        <div class="detail-license">${esc(p.license)}</div>
      </div>
      ${alertCount > 0 ? `<span class="badge-red">${alertCount} alerts</span>` : ''}
    </div>

    ${chars ? `<div class="sub-title">Characters</div><div class="char-list">${chars}</div>` : ''}

    <div class="info-grid">
      <div class="info-cell"><div class="info-cell-label">IP</div><div class="info-cell-value">${esc(p.ip || '—')}</div></div>
      <div class="info-cell"><div class="info-cell-label">Discord</div><div class="info-cell-value">${esc(p.discord || '—')}</div></div>
      <div class="info-cell"><div class="info-cell-label">Steam</div><div class="info-cell-value">${esc(p.steam || '—')}</div></div>
      <div class="info-cell"><div class="info-cell-label">First seen</div><div class="info-cell-value">${fmtDate(p.created_at)}</div></div>
    </div>

    <div class="sub-title">Recent Events</div>
    <div id="detail-events">
      ${(data.events || []).map(e => `
        <div class="event-row ${e.flagged ? 'flagged' : ''}">
          <span class="${e.flagged ? 'badge-red' : 'badge-indigo'}">${esc(e.type)}</span>
          <span style="flex:1;color:var(--muted);overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(JSON.stringify(e.data))}</span>
          <span style="color:var(--muted);flex-shrink:0">${fmtDate(e.created_at)}</span>
        </div>
      `).join('') || '<div style="color:var(--muted);padding:8px">No events</div>'}
    </div>

    <div class="sub-title">Sessions</div>
    <div>
      ${(data.sessions || []).map(s => `
        <div class="event-row">
          <span style="color:var(--text)">${fmtDate(s.joined_at)}</span>
          <span style="color:var(--muted)">${s.left_at ? '→ ' + fmtDate(s.left_at) : '<span style="color:#4ade80">online</span>'}</span>
          ${s.reason ? `<span style="color:var(--muted)">${esc(s.reason)}</span>` : ''}
        </div>
      `).join('') || '<div style="color:var(--muted);padding:8px">No sessions</div>'}
    </div>

    <div class="sub-title">Admin Notes</div>
    <div class="note-form">
      <input class="input" id="note-input" placeholder="Add a note…" />
      <button class="btn" onclick="submitNote(${p.id})">Save</button>
    </div>
    <div id="note-list">
      ${(data.notes || []).map(n => `
        <div class="note-card">
          <div class="note-text">${esc(n.note)}</div>
          <div class="note-meta">${esc(n.admin)} · ${fmtDate(n.created_at)}</div>
        </div>
      `).join('') || '<div style="color:var(--muted);font-size:13px">No notes</div>'}
    </div>
  `;

  showPage('player-detail');
}

function renderLogs(rows) {
  const tbody = document.getElementById('log-table');
  if (!rows || rows.length === 0) {
    tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;color:var(--muted);padding:32px">No events found</td></tr>';
    return;
  }
  tbody.innerHTML = rows.map(e => `
    <tr>
      <td><span class="${e.flagged ? 'badge-red' : 'badge-indigo'}">${esc(e.type)}</span></td>
      <td>${e.player_name ? `<span class="link" onclick="openPlayerDetail(${e.player_id})">${esc(e.player_name)}</span>` : '<span style="color:var(--muted)">—</span>'}</td>
      <td class="mono" style="max-width:280px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(JSON.stringify(e.data))}</td>
      <td style="color:var(--muted);white-space:nowrap">${fmtDate(e.created_at)}</td>
    </tr>
  `).join('');
}

// ─── Actions ─────────────────────────────────────────────────────────────────
window.openPlayerDetail = function(id) {
  requestData('player_detail', { id });
};

window.submitNote = function(playerId) {
  const input = document.getElementById('note-input');
  const note = (input?.value || '').trim();
  if (!note) return;
  postNUI('addNote', { playerId, note });
  input.value = '';
  // Refresh notes (optimistic)
  setTimeout(() => requestData('player_detail', { id: playerId }), 300);
};

// ─── Toasts ──────────────────────────────────────────────────────────────────
function applyToastTemplate(type, alert) {
  const cfg = state.toast;
  const tpl = (cfg.messages && (cfg.messages[type] || cfg.messages.default)) || '⚠️ {type}\n👤 {player}';
  const data = alert.data || {};
  const d    = data.detail || data;
  const pos  = d.pos || {};
  return tpl
    .replace('{type}',        type)
    .replace('{player}',      esc(data.name || '—'))
    .replace('{server_id}',   alert.server_id != null ? alert.server_id : '?')
    .replace('{speed}',       Number(d.speed  || 0).toFixed(1))
    .replace('{dist}',        Number(d.dist   || 0).toFixed(1))
    .replace('{last_health}', d.lastHealth || 0)
    .replace('{health}',      d.health     || 0)
    .replace('{amount}',      Number(d.amount || 0).toLocaleString('en-US'))
    .replace('{action}',      d.actionType || '?')
    .replace('{x}',           Number(pos.x  || 0).toFixed(1))
    .replace('{y}',           Number(pos.y  || 0).toFixed(1))
    .replace('{z}',           Number(pos.z  || 0).toFixed(1));
}

function showToast(alert) {
  if (!state.toast.enabled) return;
  const container = document.getElementById('toast-container');
  const text = applyToastTemplate(alert.type, alert);
  const lines = text.split('\n');
  const toast = document.createElement('div');
  toast.className = 'toast';
  toast.innerHTML = `
    <div class="toast-header">
      <span class="toast-icon">${lines[0].match(/^(\S+)/)?.[1] || '⚠️'}</span>
      <span class="toast-title">${esc(lines[0].replace(/^\S+\s*/, ''))}</span>
      <button class="toast-close" onclick="this.parentElement.parentElement.remove()">✕</button>
    </div>
    ${lines.slice(1).map(l => `<div class="toast-line">${esc(l)}</div>`).join('')}
  `;
  container.appendChild(toast);
  setTimeout(() => toast.classList.add('toast-out'), state.toast.duration - 300);
  setTimeout(() => toast.remove(), state.toast.duration);
}

// ─── Message handler (FiveM NUI) ─────────────────────────────────────────────
window.addEventListener('message', (ev) => {
  const msg = ev.data;
  if (!msg || !msg.action) return;

  switch (msg.action) {
    case 'initConfig':
      if (msg.toast) state.toast = msg.toast;
      break;

    case 'open':
      document.getElementById('root').classList.remove('hidden');
      state.panelOpen = true;
      if (msg.charFields) state.charFields = msg.charFields;
      if (msg.toast) state.toast = msg.toast;
      showPage('overview');
      requestData('overview');
      break;

    case 'close':
      document.getElementById('root').classList.add('hidden');
      state.panelOpen = false;
      break;

    case 'dataResponse':
      if (msg.page === 'overview')       renderOverview(msg.data);
      else if (msg.page === 'players')   renderPlayers(msg.data);
      else if (msg.page === 'player_detail') renderPlayerDetail(msg.data);
      else if (msg.page === 'logs')      renderLogs(msg.data);
      break;

    case 'setToastEnabled':
      state.toast.enabled = msg.enabled;
      break;

    case 'liveAlert':
      showToast(msg.data);
      if (state.page === 'overview') requestData('overview');
      break;
  }
});

// ─── UI event listeners ──────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  // Nav tıklamaları
  document.querySelectorAll('.nav-item').forEach(item => {
    item.addEventListener('click', () => {
      const page = item.dataset.page;
      showPage(page);
      if (page === 'overview') requestData('overview');
      else if (page === 'players') {
        state.players = { page: 1, search: '' };
        requestData('players', state.players);
      } else if (page === 'logs') {
        state.logs = { page: 1, filter: '', flagged: false };
        requestData('logs', state.logs);
      }
    });
  });

  // Kapat
  document.getElementById('close-btn').addEventListener('click', () => {
    postNUI('close');
    document.getElementById('root').classList.add('hidden');
  });

  // ESC ile kapat
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') document.getElementById('close-btn').click();
  });

  // Oyuncu arama
  document.getElementById('player-search-btn').addEventListener('click', () => {
    state.players.search = document.getElementById('player-search').value;
    state.players.page = 1;
    requestData('players', state.players);
  });
  document.getElementById('player-search').addEventListener('keydown', e => {
    if (e.key === 'Enter') document.getElementById('player-search-btn').click();
  });

  // Players geri
  document.getElementById('back-to-players').addEventListener('click', () => {
    showPage('players');
    requestData('players', state.players);
  });

  // Log filtresi
  document.getElementById('log-filter-btn').addEventListener('click', () => {
    state.logs.filter  = document.getElementById('log-type-filter').value;
    state.logs.flagged = document.getElementById('log-flagged-only').checked;
    state.logs.page    = 1;
    requestData('logs', state.logs);
  });
});

// ─── Auto-refresh (every 5s while panel is open) ─────────────────────────────
setInterval(() => {
  if (!state.panelOpen) return;
  if (state.page === 'overview') requestData('overview');
  else if (state.page === 'players') requestData('players', state.players);
  else if (state.page === 'player-detail' && state.selectedPlayer) requestData('player_detail', { id: state.selectedPlayer });
  else if (state.page === 'logs') requestData('logs', state.logs);
}, 5000);

// ─── Helpers ─────────────────────────────────────────────────────────────────
function setText(id, val) {
  const el = document.getElementById(id);
  if (el) el.textContent = val;
}

function esc(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function fmtDate(str) {
  if (!str) return '—';
  return new Date(str).toLocaleString('en-GB', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false,
  });
}
