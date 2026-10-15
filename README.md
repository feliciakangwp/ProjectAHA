# Project AHA — Finance Transformation Tracker

A single-page dashboard (`index.html`) for tracking work across the Project AHA
initiatives (ORION, POLARIS, Payment Transformation, and any you add).
Data is stored in Supabase; people sign in with email and password.

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
- **Unlimited nesting**: Track 1 → 1a → 1a.1 → 1a.1.1 … Codes renumber automatically.
- **Roll-up status**: a track or parent item shows the *lowest* status of its sub-items
  (Thoughts < Pending User < Planning < Developing < IT Testing < User Testing < Completed). Void items are ignored.
- **Start dates and deadlines** with a date picker and "N days left" / "Overdue by N days".
- **Links** between an item and other initiatives.
- **Export Excel**, **Backup** (JSON) and, for editors, **Restore**.
- **Live updates**: changes made in one browser appear in every other open browser.

## Supabase setup
1. In the Supabase SQL Editor, run `supabase/setup.sql`. It creates the `initiatives`,
   `work_items` and `editors` tables, turns on Row Level Security, enables realtime and
   loads the current data. It is safe to run again.
2. **Authentication → URL Configuration**: set **Site URL** to where the dashboard is hosted
   (for GitHub Pages: `https://feliciakangwp.github.io/ProjectAHA/`) and add the same address
   under **Redirect URLs**. Invitation and password-reset links return there.
3. **Authentication → Users → Invite user** to give someone access. They receive an email,
   open the link, and set their password on the dashboard.

The project URL and publishable key are in `index.html` (`SUPABASE_URL`, `SUPABASE_KEY`).
The publishable key is designed to be public; access is enforced by the database policies.

## Who can do what
- **Any signed-in user** can view everything and export.
- **Editors** (emails in the `editors` table) can add, edit, delete, and restore backups.
  Add an editor in the SQL Editor:
  ```sql
  insert into public.editors (email) values ('name@example.com');
  ```

## Hosting
Serve the folder over HTTPS, for example with GitHub Pages
(**Settings → Pages → Deploy from a branch**). The page loads supabase-js, SheetJS and
Google Fonts from public CDNs, so those must be reachable from the viewer's network.
