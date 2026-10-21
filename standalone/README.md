# Project AHA tracker (standalone)

A finance-transformation programme dashboard plus a 3D "Smart City" view of the same data.
This copy has **no sign-in and no built-in database**: all loading and saving goes through
**`adapter.js`**, which by default stores data in the browser. To use a real database, replace
the three functions in `adapter.js`. Nothing else needs to change.

## Files

| File | What it is |
|---|---|
| `index.html` | The dashboard (single file: HTML, CSS and JavaScript). |
| `city.html` | The 3D Smart City (Three.js), read-only, same data. |
| `adapter.js` | **The data connection.** `load()`, `save(change)`, `subscribe(onChange)`. Browser storage by default. |
| `data.js` | Starting data (`window.AHA_SEED`), in the dashboard's Backup format. Used the first time the page opens. |
| `schema.sql` | Suggested SQL tables if you connect a database (PostgreSQL syntax). |

Open `index.html` in a browser (or serve the folder with any static web server). The page loads
SheetJS (Excel export), Three.js (city), and Google Fonts from public CDNs.

## Connecting a database (for whoever builds it)

`adapter.js` defines `window.AHA_ADAPTER` with:

- **`load()`** → `Promise<{ initiatives, items, okrs, results }>`. Every record, in the shapes
  documented at the top of `adapter.js`. Called on page load and after `subscribe` reports a change.
- **`save(change)`** → `Promise`. Called once per edit, one at a time, in order.
  `change.upsert.<table>` holds full records to insert or replace by `id`;
  `change.remove.<table>` holds ids to delete. Tables: `initiatives`, `items`, `okrs`, `results`.
  Throw an `Error` with a readable message on failure: the page shows it in a red banner and reloads.
- **`subscribe(onChange)`** (optional). Call `onChange()` when data changes elsewhere (another user,
  a server push, polling); the page reloads quietly. Return an unsubscribe function.
- **`label`**: short text shown at the top of the dashboard, e.g. "Saved to Postgres".

The page creates ids (`crypto.randomUUID()`), timestamps and ordering itself, and already sends
everything needed for a delete: a parent's sub-items, an OKR's results. It only deletes an
initiative once it has no tracks and no OKRs. A typical server version is a small API
(e.g. `GET /data`, `POST /save`) and an adapter that calls it with `fetch`; `schema.sql` shows
matching tables with the camelCase ↔ snake_case mapping beside each column.

To move existing data in: the dashboard's **Backup** button downloads exactly the
`{ initiatives, items, okrs, results }` object, and **Restore** loads one (it calls `save` for every record).

## What the app does (keep this behaviour)

- **Hierarchy**: initiatives → tracks (top-level items) → sub-items of any depth (`parentId`).
  Codes are computed from order: Track 1 → 1a → 1a.1 → 1a.1.1.
- **Statuses**, lowest to highest: Thoughts, Pending User, Planning, Developing, IT Testing,
  User Testing, Completed, plus Void. A parent's status is the **lowest** status of its non-Void
  sub-items (computed in the page; not stored). Progress = completed ÷ non-Void lowest-level items.
- **Overview / initiative tabs**, each with **Work | Scorecard**:
  - Work: **By track** board (column per track, cards with compact sub-item lists, "+ Add 1d" and
    "+ Add Track 7" quick add), **By status** board (drag between columns), **Roadmap**
    (timeline from start date to deadline, or a "Next 2 quarters" board).
  - Scorecard: the initiative's **North Star** and **OKRs** (baseline, optional target, results
    over time; ▲/▼ vs baseline as improved/fell depending on direction; health On track / At risk /
    Off track / Achieved; chart per OKR with baseline and target lines; results editable).
- **Links**: an item can also appear in other initiatives (`links`); unlink from either side.
- **Smart City** (`city.html`): each initiative is a plot; each track a building by size
  (1 item swing, 2 garden, 3–4 pavilion, 5–7 house, 8+ tower) built up in proportion to its
  completed items (solid = built, blue blueprint = to build, crane = under way, flag = 100%).
- Excel export, JSON backup/restore, light/dark mode, live refresh via `subscribe`.

This copy has no sign-in, so **everyone who can open it can edit**. If you add accounts, make
`canEdit()` in `index.html` (in the "data" section) return whether the current user may edit:
the page already hides every add/edit/delete control when it returns false.
