/* =====================================================================
   Project AHA tracker: data adapter
   ---------------------------------------------------------------------
   The dashboard (index.html) and the Smart City (city.html) read and
   write ALL data through this one object. To use your own database,
   replace the three functions below; nothing else needs to change.

   Data shape (the same as the dashboard's Backup file):
     {
       initiatives: [{ id, name, description, northStar, order, createdAt }],
       items:       [{ id, initiativeId, parentId|null, name, status, prevStatus?,
                       startDate:'YYYY-MM-DD'|'', deadline:'YYYY-MM-DD'|'',
                       owner, notes, links:[initiativeId…], order, createdAt, updatedAt }],
       okrs:        [{ id, initiativeId, objective, keyResult, unit, direction:'increase'|'decrease',
                       baseline:number, baselineDate:'YYYY-MM-DD', target:number|null,
                       targetDate:'YYYY-MM-DD'|'', owner, order, createdAt, updatedAt }],
       results:     [{ id, okrId, value:number, measuredOn:'YYYY-MM-DD', note, createdAt }]
     }
   ids are UUID strings created by the page (crypto.randomUUID()).

   This default version keeps everything in the browser (localStorage),
   starting from the sample data in data.js. It works offline with no
   server, but each browser has its own copy.
   ===================================================================== */
(function () {
  const KEY = 'projectAHA.standalone.db.v1';
  const TABLES = ['initiatives', 'items', 'okrs', 'results'];
  const clone = o => JSON.parse(JSON.stringify(o));
  const empty = () => ({ initiatives: [], items: [], okrs: [], results: [] });

  function read() {
    try { const s = JSON.parse(localStorage.getItem(KEY)); if (s && TABLES.every(t => Array.isArray(s[t]))) return s; } catch (e) {}
    const seed = window.AHA_SEED ? clone(window.AHA_SEED) : empty();
    TABLES.forEach(t => { if (!Array.isArray(seed[t])) seed[t] = []; });
    return seed;
  }
  function write(data) { localStorage.setItem(KEY, JSON.stringify(data)); }

  window.AHA_ADAPTER = {
    /** Shown on the dashboard next to the theme button, e.g. "Saved in this browser". */
    label: 'Saved in this browser',

    /** Return every record. Called on page load and after subscribe() reports a change. */
    async load() {
      return clone(read());
    },

    /**
     * Apply one change. Called after every edit, one call at a time, in order.
     *   change.upsert: { initiatives:[], items:[], okrs:[], results:[] }  full records to insert or replace (match on id)
     *   change.remove: { initiatives:[ids], items:[ids], okrs:[ids], results:[ids] }
     * Throw an Error (with a readable .message) if it fails: the page shows the message and reloads.
     * The page already sends a parent's sub-items when it deletes a parent, an OKR's results when it
     * deletes an OKR, and only deletes an initiative once it has no tracks and no OKRs.
     */
    async save(change) {
      const data = read();
      TABLES.forEach(t => {
        const rm = new Set((change.remove && change.remove[t]) || []);
        if (rm.size) data[t] = data[t].filter(r => !rm.has(r.id));
        ((change.upsert && change.upsert[t]) || []).forEach(rec => {
          const i = data[t].findIndex(r => r.id === rec.id);
          if (i >= 0) data[t][i] = clone(rec); else data[t].push(clone(rec));
        });
      });
      write(data);
    },

    /**
     * Optional: call onChange() whenever the data changes somewhere else (another tab, another user,
     * a server push). The page then calls load() again. Return a function that stops listening.
     * Here: other tabs of this browser.
     */
    subscribe(onChange) {
      const h = e => { if (e.key === KEY) onChange(); };
      window.addEventListener('storage', h);
      return () => window.removeEventListener('storage', h);
    },
  };
})();
