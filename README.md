# Project AHA — Finance Transformation Tracker

A single-page dashboard (`index.html`) for tracking work across the Project AHA
initiatives (ORION, POLARIS, Payment Transformation, and any you add).
Data is stored in Supabase; people sign in with email and password.

## Features
- **Overview** of Project AHA: overall progress, status mix, initiative cards with per-track status, overdue / upcoming deadlines.
- **Initiative view** with a **Checklist** (nested tree) and **Board** (drag cards between status columns).
- **Unlimited nesting**: Track 1 → 1a → 1a.1 → 1a.1.1 … Codes renumber automatically.
- **Roll-up status**: a track or parent item shows the *lowest* status of its sub-items
  (Thoughts < Pending User < Planning < Developing < IT Testing < User Testing < Completed). Void items are ignored.
- **Deadlines** with a date picker and "N days left" / "Overdue by N days".
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
