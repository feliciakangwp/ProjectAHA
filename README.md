# Project AHA — Finance Transformation Tracker

A single-page dashboard (`index.html`) for tracking work across the Project AHA
initiatives (ORION, POLARIS, Payment Transformation, and any you add).
There is no sign-in; data is kept in the browser (see **Data** below).

## Features
- **Overview** of Project AHA: overall progress, status mix, initiative cards with per-track status, overdue / upcoming deadlines.
- **Two boards on every tab:**
  - **By track** (on the overview, **By initiative**): one column per track or initiative. Each card lists its sub-items compactly and can be collapsed.
    Editors can add straight from the board: **+ Add 1d** at the foot of a track column adds the next item, and **+ Add Track 7** at the end of the board adds the next track.
  - **By status**: one column per status; drag cards to change status.
  - **Roadmap**: a timeline per initiative (and across all initiatives on the overview). One lane per track,
    one row per item, drawn from its start date to its deadline; a deadline alone shows as a milestone.
    A today line, overdue outlines, and undated items listed so nothing is hidden.
    **Next 2 quarters** switches to a simple board: Overdue, This quarter and Next quarter, with open items
    placed by deadline and grouped by track.
- **Scorecard** (Work | Scorecard switch on every tab): each initiative's **North Star** and its **OKRs**.
  An OKR has an objective, a key result, a unit, whether higher or lower is better, a **baseline**, and an
  optional target and target date. Record results as they come in; cards show the latest value, ▲/▼ versus
  the baseline (improved or fell), progress to target and a health label (On track / At risk / Off track /
  Achieved). Click an OKR for a chart of results against the baseline and target.
- **Smart City** (`city.html`, the 🏙 Smart City button): Project AHA as a 3D new town built with Three.js.
  Each initiative is a named plot around the town plaza; each track is a building sized by its number of
  work items (1 swing, 2 garden, 3–4 pavilion, 5–7 house, 8+ tower). The structure rises with its items'
  stages (Developing counts half; from IT Testing on it stands; blue blueprint = still to build), and each
  track's status sets the scene on its site: a "Future development space" sign (Thoughts), workers
  planning round a table and whiteboard (Pending User, Planning), construction with scaffolding, crane
  and builders (Developing), an inspector in a safety helmet (IT Testing), a family with children and a
  dog viewing the place (User Testing), and residents, string lights and flowers (Completed).
  Old villages lie outside the town wall, cars circle the ring road and shooting stars cross the sky.
  Hover a building for its progress, click a plot to fly there and list its tracks. The details panel and
  the key fold away to small chips (the choice is remembered) so the city can be seen. Live, read-only.
- **Unlimited nesting**: Track 1 → 1a → 1a.1 → 1a.1.1 … Codes renumber automatically.
- **Roll-up status**: a track or parent item shows the *lowest* status of its sub-items
  (Thoughts < Pending User < Planning < Developing < IT Testing < User Testing < Completed). Void items are ignored.
- **Start dates and deadlines** with a date picker and "N days left" / "Overdue by N days".
- **Links** between an item and other initiatives.
- **Export Excel**, **Backup** (JSON) and, for editors, **Restore**.
- **Live updates** between open tabs in the same browser.
- **Light / dark mode**: follows the device until you pick one with the ☾ Dark / ☀ Light button; the choice is remembered in that browser.

## Data: no sign-in, no Supabase
There is no login and no online database. Anyone who opens the page can view and edit.
All loading and saving goes through **`adapter.js`**, which keeps the data **in the browser**
(localStorage), so:

- **Each browser has its own copy.** Changes made on one computer do not appear on another.
- The first time a browser opens the page it starts from **`data.js`** (the starting data).
- To move data between browsers or people: **Backup** downloads a JSON file, **Restore** loads one.
- Clearing the browser's site data deletes that browser's copy, so take a Backup now and then.

To update the starting data everyone gets, replace the contents of `data.js` with a Backup file
(keep `window.AHA_SEED =` at the start).

### Connecting a database later
Replace the functions in `adapter.js`; nothing else needs to change:
- `load()` returns `{ initiatives, items, okrs, results }` (the Backup format, described at the top of `adapter.js`).
- `save(change)` applies one edit: `change.upsert.<table>` holds full records to insert or replace by id,
  `change.remove.<table>` holds ids to delete. Throw an `Error` to show a message on the page.
- `subscribe(onChange)` (optional) calls `onChange()` when data changes elsewhere, for live updates.
- `label` is the short text shown at the top of the dashboard, e.g. "Saved in this browser".

`schema.sql` suggests matching tables (PostgreSQL). If you add accounts, make `canEdit()` in
`index.html` return whether the current user may edit; the page already hides every edit control
when it returns false.

## Files
| File | What it is |
|---|---|
| `index.html` | The dashboard. |
| `city.html` | The 3D Smart City (read-only view of the same data). |
| `adapter.js` | The data connection (browser storage). |
| `data.js` | Starting data, in the Backup format. |
| `schema.sql` | Suggested tables for connecting a database. |

## Hosting
Serve the folder from any static host, for example GitHub Pages
(**Settings → Pages → Deploy from a branch**), or open `index.html` directly. The page loads SheetJS
(Excel export), Three.js (Smart City) and Google Fonts from public CDNs.
