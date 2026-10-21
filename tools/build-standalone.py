#!/usr/bin/env python3
"""Build a copy of the dashboard and Smart City that does not use Supabase or sign-in.

    python3 tools/build-standalone.py [backup.json]

Reads index.html and city.html from the repository root and writes standalone/:
  index.html, city.html  same pages, with data loading/saving routed through adapter.js
  adapter.js             the only file to change to connect another database (browser storage by default)
  data.js                starting data, in the dashboard's Backup format
  schema.sql             a plain SQL schema matching the data, for whoever wires up a database
  README.md              instructions for the person (or AI assistant) taking it over

backup.json: optional file from the dashboard's Backup button; defaults to tools/standalone-seed.json.
Every replacement is checked, so the script stops if the source pages change shape.
"""
import json, pathlib, re, shutil, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOLS = ROOT / 'tools'
OUT = ROOT / 'standalone'

def swap(text, old, new, what, count=1):
    n = text.count(old)
    if n != count:
        sys.exit(f'build-standalone: expected {count} x {what}, found {n}. Update tools/build-standalone.py.')
    return text.replace(old, new)

def cut(text, start, end, new, what):
    a = text.find(start); b = text.find(end, a + 1)
    if a < 0 or b < 0:
        sys.exit(f'build-standalone: could not find {what}. Update tools/build-standalone.py.')
    return text[:a] + new + text[b:]

def leftovers(text, name, words):
    hits = [f'  line {n}: {line.strip()[:140]}' for n, line in enumerate(text.split('\n'), 1) if any(w in line for w in words)]
    if hits:
        sys.exit(f'build-standalone: Supabase/sign-in code is still in standalone/{name}:\n' + '\n'.join(hits) + '\nUpdate tools/build-standalone.py.')

SUPABASE_TAG = '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.117.2/dist/umd/supabase.js"></script>'
LOCAL_TAGS = '<script src="data.js"></script>\n<script src="adapter.js"></script>'

def build_index(src):
    s = swap(src, SUPABASE_TAG, LOCAL_TAGS, 'supabase script tag')
    # data + auth sections -> adapter-backed data section
    s = cut(s, '/* ------------------------------------------------------- supabase data */',
            '/* --------------------------------------------------------- derivations */',
            (TOOLS / 'standalone-data-section.js').read_text(), 'data and auth sections')
    # render: no sign-in screen
    s = cut(s, "  if (auth.screen !== 'app') {", "  index();\n", '', 'sign-in branch in render()')
    # header: no email / role / live status / sign out
    s = cut(s, '        <div class="userbar">', '          ${themeButton()}',
            '        <div class="userbar">\n          <span class="mode-note" style="margin:0"><span class="dot" style="background:var(--s-done)"></span>${esc((ADAPTER && ADAPTER.label) || \'\')}</span>\n',
            'user bar')
    s = swap(s, '          <button class="btn sm ghost" data-act="sign-out">Sign out</button>\n', '', 'sign-out button')
    # events: no auth buttons / forms / sign out
    s = swap(s, """  const authBtn = e.target.closest('[data-auth]');
  if (authBtn) { if (authBtn.dataset.auth === 'forgot') forgotPassword(); else { auth.screen = 'signin'; auth.message = ''; render(); } return; }
""", '', 'auth click handler')
    s = swap(s, "  if (a === 'sign-out') { signOut(); return; }\n", '', 'sign-out handler')
    s = swap(s, "  if (e.target.id === 'authForm' && !auth.busy) handleAuthSubmit(e.target);\n  else if (e.target.matches('[data-qa-form]') && canEdit()) submitQuickAdd(e.target);",
             "  if (e.target.matches('[data-qa-form]') && canEdit()) submitQuickAdd(e.target);", 'auth submit handler')
    s = swap(s, '\ninitAuth();\n', '\nstart();\n', 'start call')
    s = swap(s, '// Backups from before the move to Supabase used short ids like "orion"; give those new UUIDs.',
             '// Very old backups used short ids like "orion"; give those new UUIDs.', 'restore comment')
    # Supabase-specific wording in set-up notes
    s = swap(s, "Run <b>supabase/scorecard.sql</b> once in the Supabase SQL Editor\n    (open it on GitHub, copy everything, paste into a new query and click Run), then reload this page.",
             "Add the okrs and okr_results tables to the database (see schema.sql), then reload this page.", 'scorecard set-up note')
    s = swap(s, "To turn on start dates, run this once in the Supabase SQL Editor:", "To turn on start dates, add this column to the database:", 'start date note')
    leftovers(s, 'index.html', ['supabase', 'Supabase', 'SUPABASE', 'signOut', 'initAuth', 'store.sb', 'store.session'])
    return s

CITY_DATA = """let raw = { initiatives: [], items: [] };
const ADAPTER = window.AHA_ADAPTER;
// The adapter returns the dashboard's record shape; the city works on these fields.
async function loadData() {
  if (!ADAPTER) throw new Error('adapter.js did not load');
  const d = await ADAPTER.load();
  raw = {
    initiatives: (d.initiatives || []).map(i => ({ id: i.id, name: i.name, description: i.description || '', north_star: i.northStar || '', sort_order: i.order ?? 0 })),
    items: (d.items || []).map(i => ({ id: i.id, initiative_id: i.initiativeId, parent_id: i.parentId || null, name: i.name, status: i.status, sort_order: i.order ?? 0 })),
  };
}
"""

def build_city(src):
    s = swap(src, SUPABASE_TAG, LOCAL_TAGS, 'supabase script tag')
    s = cut(s, '// Same project and key as index.html', 'const STATUSES = [', '', 'Supabase constants')
    s = cut(s, 'let sb = null;', '// Roll the tracker up', CITY_DATA + '\n', 'city data loading')
    s = cut(s, "  if (!window.supabase || !window.supabase.createClient)", '  try { await loadData(); }', '', 'city sign-in check')
    s = cut(s, "  sb.channel('aha-city')", '}\nasync function refresh()',
            "  if (ADAPTER && typeof ADAPTER.subscribe === 'function') ADAPTER.subscribe(() => { clearTimeout(timer); timer = setTimeout(refresh, 600); });\n",
            'city live updates')
    leftovers(s, 'city.html', ['supabase', 'Supabase', 'SUPABASE', 'sb.', 'getSession'])
    return s

def main():
    seed_path = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else TOOLS / 'standalone-seed.json'
    seed = json.loads(seed_path.read_text())
    for t in ['initiatives', 'items', 'okrs', 'results']:
        seed.setdefault(t, [])
        if not isinstance(seed[t], list):
            sys.exit(f'build-standalone: {seed_path} is not a dashboard backup ("{t}" is not a list).')
    seed = {t: seed[t] for t in ['initiatives', 'items', 'okrs', 'results']}
    OUT.mkdir(exist_ok=True)
    (OUT / 'index.html').write_text(build_index((ROOT / 'index.html').read_text()))
    (OUT / 'city.html').write_text(build_city((ROOT / 'city.html').read_text()))
    shutil.copy(TOOLS / 'standalone-adapter.js', OUT / 'adapter.js')
    (OUT / 'data.js').write_text('/* Starting data for the Project AHA tracker, in the dashboard\'s Backup format.\n'
        '   Used by adapter.js the first time the page opens in a browser. Replace it with a newer\n'
        '   Backup file\'s contents (keep the "window.AHA_SEED =" at the start), or use Restore in the dashboard. */\n'
        'window.AHA_SEED = ' + json.dumps(seed, indent=1, ensure_ascii=False) + ';\n')
    shutil.copy(TOOLS / 'standalone-schema.sql', OUT / 'schema.sql')
    shutil.copy(TOOLS / 'standalone-README.md', OUT / 'README.md')
    n = {t: len(v) for t, v in seed.items()}
    print(f'standalone/ written: {n["initiatives"]} initiatives, {n["items"]} work items, {n["okrs"]} OKRs, {n["results"]} OKR results')

if __name__ == '__main__':
    main()
