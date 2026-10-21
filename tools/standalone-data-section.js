/* -------------------------------------------------------------- data */
// All loading and saving goes through window.AHA_ADAPTER (adapter.js), so a different
// database can be plugged in by replacing that one file. There is no sign-in: everyone edits.
const ADAPTER = window.AHA_ADAPTER;

let db = { initiatives: [], items: [], okrs: [], results: [] }, ui;
const store = {
  loaded: false, loading: false, hasStartDate: true, hasOkrs: true, hasNorthStar: true,
  live: 'on', queue: Promise.resolve(),
};
const auth = { screen: 'app' };
const canEdit = () => true;

function loadUI() {
  try { ui = JSON.parse(localStorage.getItem(UI_KEY)) || {}; } catch { ui = {}; }
  ui = Object.assign({ view: 'overview', track: 'all', mode: 'tracks', search: '', status: 'all', hideDone: false, overdueOnly: false, collapsed: [], page: 'work', rmZoom: 'months', rmUnscheduled: true, rmCollapsed: [] }, ui);
  normalizeMode();
}
function normalizeMode() { if (ui.mode === 'board') ui.mode = 'status'; if (!['status', 'roadmap'].includes(ui.mode)) ui.mode = 'tracks'; }
function saveUI() { try { localStorage.setItem(UI_KEY, JSON.stringify(ui)); } catch {} }

// Turn a storage error into a sentence a person can act on.
function explain(err, doing) {
  const msg = (err && (err.message || String(err))) || '';
  if (!navigator.onLine || /Failed to fetch|NetworkError|Load failed/i.test(msg)) return `Could not ${doing}: no connection to the database. Check your internet connection and try again.`;
  if (/quota/i.test(msg)) return `Could not ${doing}: browser storage is full. Use Backup, then clear old data.`;
  return `Could not ${doing}${msg ? `: ${msg}` : '.'}`;
}

// Error banner sits outside #app so re-renders do not clear it.
function showError(message, retry, kind = 'other') {
  const bar = document.getElementById('errorBar');
  bar.dataset.kind = kind;
  bar.querySelector('[data-msg]').textContent = message;
  const r = bar.querySelector('[data-retry]');
  r.hidden = !retry; r.onclick = () => { hideError(); retry(); };
  bar.hidden = false;
}
function hideError() { document.getElementById('errorBar').hidden = true; }

const asList = v => (Array.isArray(v) ? v : []);
async function loadData({ quiet = false } = {}) {
  store.loading = true;
  if (!quiet) render();
  try {
    if (!ADAPTER) throw new Error('adapter.js did not load');
    const d = await ADAPTER.load();
    db = { initiatives: asList(d.initiatives), items: asList(d.items), okrs: asList(d.okrs), results: asList(d.results) };
    db.items.forEach(i => { if (!Array.isArray(i.links)) i.links = []; if (i.deadline == null) i.deadline = ''; if (i.startDate == null) i.startDate = ''; });
    db.okrs.forEach(o => { o.baseline = Number(o.baseline); o.target = o.target === null || o.target === undefined || o.target === '' ? null : Number(o.target); });
    db.results.forEach(r => { r.value = Number(r.value); });
    store.loaded = true;
    if (document.getElementById('errorBar').dataset.kind === 'load') hideError();
  } catch (err) {
    showError(explain(err, 'load the tracker'), () => loadData(), 'load');
  } finally {
    store.loading = false;
    render();
    if (okrDetailOpen) scheduleOkrDetail();
  }
}
let renderTimer;
function scheduleRender() { clearTimeout(renderTimer); renderTimer = setTimeout(render, 60); }

// Persist changes. Callers have already applied them to `db` so the page updates instantly.
function commit({ items = [], inits = [], delItems = [], delInits = [], okrs = [], results = [], delOkrs = [], delResults = [] } = {}) {
  const plain = o => JSON.parse(JSON.stringify(o));
  const change = {
    upsert: { initiatives: inits.map(plain), items: items.map(plain), okrs: okrs.map(plain), results: results.map(plain) },
    remove: { initiatives: [...delInits], items: [...delItems], okrs: [...delOkrs], results: [...delResults] },
  };
  // One save at a time keeps quick successive edits in order.
  store.queue = store.queue.then(() => ADAPTER.save(change)).then(() => true).catch(err => {
    showError(explain(err, 'save your change') + ' Your last change was not saved; the page now shows what is stored.', null);
    loadData({ quiet: true });
    return false;
  });
  return store.queue;
}

function start() {
  loadUI();
  loadData();
  // Changes made elsewhere (another tab, another user): reload quietly.
  let t;
  if (ADAPTER && typeof ADAPTER.subscribe === 'function') ADAPTER.subscribe(() => { clearTimeout(t); t = setTimeout(() => loadData({ quiet: true }), 300); });
}

