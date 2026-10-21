-- =====================================================================
-- Project AHA tracker: suggested database schema (plain PostgreSQL)
-- Optional. Use it if you connect a SQL database in adapter.js; adapt the
-- types for other databases. Column names are snake_case; adapter.js
-- works in the page's camelCase names (mapping noted next to each column).
-- The page computes all roll-ups, progress and health itself, so the
-- database only stores the records below.
-- =====================================================================

create table initiatives (
  id          uuid primary key,                 -- id
  name        text not null,                    -- name
  description text not null default '',         -- description
  north_star  text not null default '',         -- northStar
  sort_order  integer not null default 0,       -- order
  created_at  timestamptz not null default now()-- createdAt
);

create table work_items (
  id            uuid primary key,                                         -- id
  -- an initiative cannot be deleted while it still has tracks
  initiative_id uuid not null references initiatives (id) on delete restrict, -- initiativeId
  -- null = a top-level track; deleting a parent deletes its sub-items
  parent_id     uuid references work_items (id) on delete cascade,        -- parentId
  name          text not null,                                            -- name
  status        text not null default 'Thoughts' check (status in
    ('Thoughts','Pending User','Planning','Developing','IT Testing','User Testing','Completed','Void')), -- status
  prev_status   text,                                                     -- prevStatus (status before ticked Completed)
  start_date    date,                                                     -- startDate ('' in the page when empty)
  deadline      date,                                                     -- deadline  ('' in the page when empty)
  owner         text not null default '',                                 -- owner
  notes         text not null default '',                                 -- notes
  links         uuid[] not null default '{}',                             -- links (other initiatives this item also shows in)
  sort_order    integer not null default 0,                               -- order
  created_at    timestamptz not null default now(),                       -- createdAt
  updated_at    timestamptz not null default now(),                       -- updatedAt
  check (start_date is null or deadline is null or start_date <= deadline),
  check (parent_id is distinct from id)
);
create index on work_items (initiative_id);
create index on work_items (parent_id);

create table okrs (
  id            uuid primary key,                                              -- id
  initiative_id uuid not null references initiatives (id) on delete restrict,  -- initiativeId
  objective     text not null default '',                                      -- objective
  key_result    text not null,                                                 -- keyResult
  unit          text not null default '',                                      -- unit (%, days, $ ...)
  direction     text not null default 'increase' check (direction in ('increase','decrease')), -- direction (which way is better)
  baseline      numeric not null,                                              -- baseline
  baseline_date date not null,                                                 -- baselineDate
  target        numeric,                                                       -- target (null = none)
  target_date   date,                                                          -- targetDate ('' when empty)
  owner         text not null default '',                                      -- owner
  sort_order    integer not null default 0,                                    -- order
  created_at    timestamptz not null default now(),                            -- createdAt
  updated_at    timestamptz not null default now()                             -- updatedAt
);
create index on okrs (initiative_id);

create table okr_results (
  id          uuid primary key,                                     -- id
  okr_id      uuid not null references okrs (id) on delete cascade, -- okrId
  value       numeric not null,                                     -- value
  measured_on date not null,                                        -- measuredOn
  note        text not null default '',                             -- note
  created_at  timestamptz not null default now()                    -- createdAt
);
create index on okr_results (okr_id);
