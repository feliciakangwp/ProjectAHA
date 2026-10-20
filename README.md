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
- **Scorecard** (Work | Scorecard switch on every tab): each initiative's **North Star** and its **OKRs**.
  An OKR has an objective, a key result, a unit, whether higher or lower is better, a **baseline**, and an
  optional target and target date. Record results as they come in; cards show the latest value, ▲/▼ versus
  the baseline (improved or fell), progress to target and a health label (On track / At risk / Off track /
  Achieved). Click an OKR for a chart of results against the baseline and target.
- **Smart City** (`city.html`, the 🏙 Smart City button): Project AHA as a 3D new town built with Three.js.
  Each initiative is a named plot around the town plaza; each track is a building sized by its number of
  work items (1 swing, 2 garden, 3–4 pavilion, 5–7 house, 8+ tower) that is built up piece by piece as
  its items complete (solid = built, blue blueprint = still to build, crane = under way, flag = complete).
  Old villages lie outside the town wall, cars circle the ring road and shooting stars cross the sky.
  Hover a building for its progress, click a plot to fly there and list its tracks. Live, read-only.
- **Unlimited nesting**: Track 1 → 1a → 1a.1 → 1a.1.1 … Codes renumber automatically.
- **Roll-up status**: a track or parent item shows the *lowest* status of its sub-items
  (Thoughts < Pending User < Planning < Developing < IT Testing < User Testing < Completed). Void items are ignored.
- **Start dates and deadlines** with a date picker and "N days left" / "Overdue by N days".
- **Links** between an item and other initiatives.
- **Export Excel**, **Backup** (JSON) and, for editors, **Restore**.
- **Live updates**: changes made in one browser appear in every other open browser.
- **Light / dark mode**: follows the device until you pick one with the ☾ Dark / ☀ Light button; the choice is remembered in that browser.

## Supabase setup
1. In the Supabase SQL Editor, run `supabase/setup.sql`. It creates the `initiatives`,
   `work_items`, `editors`, `okrs` and `okr_results` tables, turns on Row Level Security, enables
   realtime and loads the starting data. It is safe to run again: the starting data is only loaded
   into an empty tracker, so deleted items never come back.
   Already set up before the Scorecard existed? Run just `supabase/scorecard.sql` instead.
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
