# Project AHA — Finance Transformation Tracker

A single-file interactive dashboard (`index.html`) for tracking work across the
Project AHA initiatives (ORION, POLARIS, Payment Transformation, and any you add).

Open `index.html` in a browser — no install or server needed.

## Features
- **Overview** of Project AHA: overall progress, status mix, initiative cards with per-track status, overdue / upcoming deadlines.
- **Initiative view** with a **Checklist** (nested tree) and **Board** (drag cards between status columns).
- **Unlimited nesting**: Track 1 → 1a → 1a.1 → 1a.1.1 … Codes renumber automatically.
- **Roll-up status**: a track or parent item shows the *lowest* status of its sub-items
  (order: Thoughts < Pending User < Planning < Developing < IT Testing < User Testing < Completed). Void items are ignored.
- Completed / Void items are greyed out; changing status back restores them.
- **Deadlines** with a date picker and "N days left" / "Overdue by N days".
- **Links** between an item and other initiatives (e.g. POLARIS 1c Payments ↔ Payment Transformation).
- Add / rename / reorder / delete initiatives, tracks and items.
- **Export Excel** (Summary, all work items, one sheet per initiative), **Backup / Restore** as JSON.

## Data
- **Hosted (shared) version:** https://claude.ai/artifact/LZdG1LX3kfk6e9nrVUvzEP. Data lives in the page's
  shared database, so everyone the page is shared with sees the same, live tracker.
- **Opened as a local file:** data is saved in that browser's local storage, starting from `seed.js`.
  Use **Backup** to save a JSON file and **Restore** to load it on another machine or into the hosted version.
