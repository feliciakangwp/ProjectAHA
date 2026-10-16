-- =====================================================================
-- Project AHA tracker: Supabase setup
-- Paste into the Supabase SQL Editor and run. Safe to run more than once.
--
-- Tables
--   initiatives  ORION, POLARIS, Payment Transformation, ...
--   work_items   tracks and sub-items at any depth (Track 1 > 1a > 1a.1 ...)
--   editors      email addresses allowed to change data
--
-- Access
--   Any signed-in user can read initiatives and work_items.
--   Only users whose login email is in editors can insert, update or delete.
--   editors itself can only be changed here in the SQL Editor (or with the
--   service role key), never from the browser.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------

create table if not exists public.initiatives (
  id          uuid        primary key default gen_random_uuid(),
  name        text        not null check (length(trim(name)) > 0),
  description text        not null default '',
  sort_order  integer     not null default 0,
  created_at  timestamptz not null default now()
);

create table if not exists public.work_items (
  id            uuid        primary key default gen_random_uuid(),
  -- Restrict: an initiative can only be deleted once it has no tracks.
  initiative_id uuid        not null references public.initiatives (id) on delete restrict,
  -- null = a top-level track; otherwise the item this one sits under.
  parent_id     uuid        references public.work_items (id) on delete cascade,
  name          text        not null check (length(trim(name)) > 0),
  -- Only set on items without sub-items; a parent's status is rolled up
  -- (lowest status of its sub-items) by the dashboard.
  status        text        not null default 'Thoughts',
  -- Status before the item was ticked Completed, so unticking can restore it.
  prev_status   text,
  -- Optional; with a deadline it draws the item as a bar on the roadmap.
  start_date    date,
  deadline      date,
  owner         text        not null default '',
  notes         text        not null default '',
  -- Other initiatives this item is also linked to (initiative ids).
  links         uuid[]      not null default '{}',
  sort_order    integer     not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint work_items_status_check check (status in
    ('Thoughts','Pending User','Planning','Developing','IT Testing','User Testing','Completed','Void')),
  constraint work_items_prev_status_check check (prev_status is null or prev_status in
    ('Thoughts','Pending User','Planning','Developing','IT Testing','User Testing','Completed','Void')),
  constraint work_items_not_own_parent check (parent_id is distinct from id)
);

-- Databases set up with an earlier version of this script deleted an initiative's
-- tracks along with it. Switch that to "restrict" (safe to run repeatedly).
alter table public.work_items drop constraint if exists work_items_initiative_id_fkey;
alter table public.work_items add constraint work_items_initiative_id_fkey
  foreign key (initiative_id) references public.initiatives (id) on delete restrict;

-- Roadmap start dates (added after the first version of this script).
alter table public.work_items add column if not exists start_date date;
alter table public.work_items drop constraint if exists work_items_start_before_deadline;
alter table public.work_items add constraint work_items_start_before_deadline
  check (start_date is null or deadline is null or start_date <= deadline);

create index if not exists work_items_initiative_id_idx on public.work_items (initiative_id);
create index if not exists work_items_parent_id_idx     on public.work_items (parent_id);

-- Keep updated_at current on every change.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists work_items_set_updated_at on public.work_items;
create trigger work_items_set_updated_at
  before update on public.work_items
  for each row execute function public.set_updated_at();

create table if not exists public.editors (
  -- Stored in lower case so matching the login email is case-insensitive.
  email text primary key check (email = lower(trim(email)) and email like '%_@_%')
);

-- ---------------------------------------------------------------------
-- 2. Editors list and helper
-- ---------------------------------------------------------------------

insert into public.editors (email) values ('wanping0627@gmail.com')
on conflict (email) do nothing;

-- True when the signed-in user's email is in editors. SECURITY DEFINER lets
-- it read editors without giving users access to the whole list.
create or replace function public.is_editor()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.editors e
    where e.email = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

revoke execute on function public.is_editor() from public, anon;
grant execute on function public.is_editor() to authenticated;

-- ---------------------------------------------------------------------
-- 3. Row Level Security
-- ---------------------------------------------------------------------

alter table public.initiatives enable row level security;
alter table public.work_items  enable row level security;
alter table public.editors     enable row level security;

-- initiatives: signed-in users read; editors write.
-- Anonymous sign-ins (if ever enabled) also use the "authenticated" role,
-- so they are excluded explicitly.
drop policy if exists "Signed-in users can read initiatives" on public.initiatives;
create policy "Signed-in users can read initiatives" on public.initiatives
  for select to authenticated
  using ((select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false)) = false);

drop policy if exists "Editors can add initiatives" on public.initiatives;
create policy "Editors can add initiatives" on public.initiatives
  for insert to authenticated
  with check ((select public.is_editor()));

drop policy if exists "Editors can change initiatives" on public.initiatives;
create policy "Editors can change initiatives" on public.initiatives
  for update to authenticated
  using ((select public.is_editor()))
  with check ((select public.is_editor()));

drop policy if exists "Editors can delete initiatives" on public.initiatives;
create policy "Editors can delete initiatives" on public.initiatives
  for delete to authenticated
  using ((select public.is_editor()));

-- work_items: same rules.
drop policy if exists "Signed-in users can read work items" on public.work_items;
create policy "Signed-in users can read work items" on public.work_items
  for select to authenticated
  using ((select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false)) = false);

drop policy if exists "Editors can add work items" on public.work_items;
create policy "Editors can add work items" on public.work_items
  for insert to authenticated
  with check ((select public.is_editor()));

drop policy if exists "Editors can change work items" on public.work_items;
create policy "Editors can change work items" on public.work_items
  for update to authenticated
  using ((select public.is_editor()))
  with check ((select public.is_editor()));

drop policy if exists "Editors can delete work items" on public.work_items;
create policy "Editors can delete work items" on public.work_items
  for delete to authenticated
  using ((select public.is_editor()));

-- editors: a signed-in user can see only their own row (so the dashboard can
-- tell whether to show edit controls). No insert/update/delete policies, so
-- the list can only be changed from the SQL Editor.
drop policy if exists "Users can see their own editor row" on public.editors;
create policy "Users can see their own editor row" on public.editors
  for select to authenticated
  using (email = lower(coalesce((select auth.jwt() ->> 'email'), '')));

-- ---------------------------------------------------------------------
-- 4. Realtime: broadcast changes to other open browsers
--    (Realtime still applies the read policies above.)
-- ---------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'initiatives') then
    alter publication supabase_realtime add table public.initiatives;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'work_items') then
    alter publication supabase_realtime add table public.work_items;
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- 4b. Scorecard: North Star and OKRs (same statements as supabase/scorecard.sql)
-- ---------------------------------------------------------------------

alter table public.initiatives add column if not exists north_star text not null default '';

create table if not exists public.okrs (
  id            uuid        primary key default gen_random_uuid(),
  -- Restrict: an initiative with OKRs cannot be deleted until its OKRs are.
  initiative_id uuid        not null references public.initiatives (id) on delete restrict,
  objective     text        not null default '',
  key_result    text        not null check (length(trim(key_result)) > 0),
  unit          text        not null default '',
  -- Which way is better: 'increase' (e.g. adoption %) or 'decrease' (e.g. days to close).
  direction     text        not null default 'increase' check (direction in ('increase', 'decrease')),
  baseline      numeric     not null,
  baseline_date date        not null default current_date,
  target        numeric,
  target_date   date,
  owner         text        not null default '',
  sort_order    integer     not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table if not exists public.okr_results (
  id          uuid        primary key default gen_random_uuid(),
  okr_id      uuid        not null references public.okrs (id) on delete cascade,
  value       numeric     not null,
  measured_on date        not null default current_date,
  note        text        not null default '',
  created_at  timestamptz not null default now()
);

create index if not exists okrs_initiative_id_idx on public.okrs (initiative_id);
create index if not exists okr_results_okr_id_idx on public.okr_results (okr_id);

drop trigger if exists okrs_set_updated_at on public.okrs;
create trigger okrs_set_updated_at
  before update on public.okrs
  for each row execute function public.set_updated_at();

alter table public.okrs        enable row level security;
alter table public.okr_results enable row level security;

drop policy if exists "Signed-in users can read OKRs" on public.okrs;
create policy "Signed-in users can read OKRs" on public.okrs
  for select to authenticated
  using ((select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false)) = false);
drop policy if exists "Editors can add OKRs" on public.okrs;
create policy "Editors can add OKRs" on public.okrs
  for insert to authenticated with check ((select public.is_editor()));
drop policy if exists "Editors can change OKRs" on public.okrs;
create policy "Editors can change OKRs" on public.okrs
  for update to authenticated using ((select public.is_editor())) with check ((select public.is_editor()));
drop policy if exists "Editors can delete OKRs" on public.okrs;
create policy "Editors can delete OKRs" on public.okrs
  for delete to authenticated using ((select public.is_editor()));

drop policy if exists "Signed-in users can read OKR results" on public.okr_results;
create policy "Signed-in users can read OKR results" on public.okr_results
  for select to authenticated
  using ((select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false)) = false);
drop policy if exists "Editors can add OKR results" on public.okr_results;
create policy "Editors can add OKR results" on public.okr_results
  for insert to authenticated with check ((select public.is_editor()));
drop policy if exists "Editors can change OKR results" on public.okr_results;
create policy "Editors can change OKR results" on public.okr_results
  for update to authenticated using ((select public.is_editor())) with check ((select public.is_editor()));
drop policy if exists "Editors can delete OKR results" on public.okr_results;
create policy "Editors can delete OKR results" on public.okr_results
  for delete to authenticated using ((select public.is_editor()));

-- Live updates in other browsers.
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'okrs') then
    alter publication supabase_realtime add table public.okrs;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'okr_results') then
    alter publication supabase_realtime add table public.okr_results;
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- 5. Current data (from the live shared tracker, 13 Oct 2026)
--    Loaded only when the tracker is empty, so re-running this script never
--    brings back items that were deleted later.
-- ---------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from public.initiatives) then
    insert into public.initiatives (id, name, description, sort_order, created_at) values
      ('b8b2de30-6920-5294-b86b-e5ef6bc8a41f', 'ORION', 'Budgeting, projection & utilisation platform', 0, '2026-10-13T06:45:51.297Z'),
      ('4b7a451d-a38d-5de3-93bd-a1bf5ab14ca0', 'POLARIS', 'Debt management, fees & reconciliation', 1, '2026-10-13T06:45:51.297Z'),
      ('d971b8f4-e935-5ca6-8c85-da0c1b1d2c70', 'Payment Transformation', 'End-to-end payment process redesign', 2, '2026-10-13T06:45:51.297Z')
    on conflict (id) do nothing;

    insert into public.work_items
      (id, initiative_id, parent_id, name, status, prev_status, deadline, owner, notes, links, sort_order, created_at, updated_at)
    values
      -- ORION
      ('ebb0eb8a-e941-5a62-9c43-0614aa9d6859', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', null, 'Medium Term Projection (MTP)', 'Thoughts', null, null, '', '', '{}', 0, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* Track 1 Medium Term Projection (MTP) */,
      ('ba77a026-0785-5617-bd7e-da52b6ac5b6b', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', 'ebb0eb8a-e941-5a62-9c43-0614aa9d6859', 'Recalculation of SOF', 'IT Testing', null, null, '', '', '{}', 0, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 1a Recalculation of SOF */,
      ('270dcb8d-fdb8-58b5-981e-244c63b82bba', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', 'ebb0eb8a-e941-5a62-9c43-0614aa9d6859', 'MTP Variance after refactoring', 'IT Testing', null, null, '', '', '{}', 1, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 1b MTP Variance after refactoring */,
      ('00614862-525a-5a85-9f0c-35464198a0e0', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', 'ebb0eb8a-e941-5a62-9c43-0614aa9d6859', 'MTP Broken Linkage (Mainstreaming)', 'Developing', null, null, '', '', '{}', 2, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 1c MTP Broken Linkage (Mainstreaming) */,
      ('e4a47177-a545-56e6-8fed-0e0a7028cd82', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', null, 'Annual Budget', 'Thoughts', null, null, '', '', '{}', 1, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* Track 2 Annual Budget */,
      ('badf2681-4fea-5e68-b000-58c8f81fec7c', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', 'e4a47177-a545-56e6-8fed-0e0a7028cd82', 'When to port Annual Budget line over to MTP (after Fin Supported?)', 'Planning', null, null, '', '', '{}', 0, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 2a When to port Annual Budget line over to MTP (after Fin Suppo */,
      ('847f1eaf-ba4d-56f1-a7d1-8acbda1fa12c', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', 'e4a47177-a545-56e6-8fed-0e0a7028cd82', 'Include column in Raw Report: Budgeted amount after DY Supported, before Clarification', 'Planning', null, null, '', '', '{}', 1, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 2b Include column in Raw Report: Budgeted amount after DY Suppo */,
      ('84bbe12d-17ad-59d6-9ce9-0dcbb60de4a5', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', null, 'Block Budget', 'Thoughts', null, null, '', '', '{}', 2, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* Track 3 Block Budget */,
      ('84b314f8-18ce-5856-8e63-527b94113e1a', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '84bbe12d-17ad-59d6-9ce9-0dcbb60de4a5', 'Refactoring of Block Budget', 'Developing', null, null, '', '', '{}', 0, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 3a Refactoring of Block Budget */,
      ('99de2e97-9344-5c88-97cd-605f5b290d34', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '84bbe12d-17ad-59d6-9ce9-0dcbb60de4a5', 'Block Budget Raw Report', 'IT Testing', null, null, '', '', '{}', 1, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 3b Block Budget Raw Report */,
      ('70b4fd51-3808-52ef-9b37-4768d8b87074', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '84bbe12d-17ad-59d6-9ce9-0dcbb60de4a5', 'Block Budget Report', 'IT Testing', null, null, '', '', '{}', 2, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 3c Block Budget Report */,
      ('5f855475-e205-5824-8e8b-cb72ea4798ac', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '84bbe12d-17ad-59d6-9ce9-0dcbb60de4a5', 'Block Budget Variance Report', 'IT Testing', null, null, '', '', '{}', 3, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 3d Block Budget Variance Report */,
      ('271c9959-da5e-5850-a0d4-ffb3880b3574', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '84bbe12d-17ad-59d6-9ce9-0dcbb60de4a5', 'Block Budget Projection Parameter', 'Developing', null, null, '', '', '{}', 4, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 3e Block Budget Projection Parameter */,
      ('23c49949-d32b-503d-98ce-cd6fc1388438', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', null, 'Expenditure & Utilisation', 'Thoughts', null, null, '', '', '{}', 3, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* Track 4 Expenditure & Utilisation */,
      ('8c5b4efe-5ffc-5a46-b526-840f44f40b98', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '23c49949-d32b-503d-98ce-cd6fc1388438', 'Uploading of Expenditure GL', 'User Testing', null, null, '', '', '{}', 0, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 4a Uploading of Expenditure GL */,
      ('2144b124-fe79-58ba-ad96-4918758b47e9', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '23c49949-d32b-503d-98ce-cd6fc1388438', 'Calculation of Project Utilisation', 'User Testing', null, null, '', '', '{}', 1, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 4b Calculation of Project Utilisation */,
      ('1f7b8f65-fe3f-56d0-9d94-3eebd066a405', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '23c49949-d32b-503d-98ce-cd6fc1388438', 'Calculation of individual line utilisation', 'Pending User', null, null, '', '', '{}', 2, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 4c Calculation of individual line utilisation */,
      ('3f236dec-4ab4-5e34-8cbc-c0fd25c27845', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '23c49949-d32b-503d-98ce-cd6fc1388438', 'Provide expenditure access to specific Branch Rep (tag to BR Account)', 'Developing', null, null, '', '', '{}', 3, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 4d Provide expenditure access to specific Branch Rep (tag to BR */,
      ('b61ffa98-60e3-5c43-bd07-e540bd789fb3', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '23c49949-d32b-503d-98ce-cd6fc1388438', 'AOR', 'User Testing', null, null, '', '', '{}', 4, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 4e AOR */,
      ('10c9cded-93ee-5c5c-9a97-1dea35bbeb60', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', null, 'Dashboard', 'Thoughts', null, null, '', '', '{}', 4, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* Track 5 Dashboard */,
      ('807255af-47bf-5f1c-9338-f8ba47e953e8', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '10c9cded-93ee-5c5c-9a97-1dea35bbeb60', 'Outstanding To Do Items', 'IT Testing', null, null, '', '', '{}', 0, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 5a Outstanding To Do Items */,
      ('87750d7b-b06b-5030-93c1-9d5dbfe2ba19', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '10c9cded-93ee-5c5c-9a97-1dea35bbeb60', 'Project Budget', 'IT Testing', null, null, '', '', '{}', 1, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 5b Project Budget */,
      ('c3f26669-ea8f-5484-9d27-be2e28b19847', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '10c9cded-93ee-5c5c-9a97-1dea35bbeb60', 'Project Expenditure & Utilisation', 'IT Testing', null, null, '', '', '{}', 2, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 5c Project Expenditure & Utilisation */,
      ('96898355-896a-5b48-88c1-d8888732b3cb', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '10c9cded-93ee-5c5c-9a97-1dea35bbeb60', 'Individual lines budget by Branch', 'Thoughts', null, null, '', '', '{}', 3, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 5d Individual lines budget by Branch */,
      ('cc0ceb85-8398-534e-ba30-2303fc9e7431', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '10c9cded-93ee-5c5c-9a97-1dea35bbeb60', 'Individual lines Expenditure & Utilisation', 'Thoughts', null, null, '', '', '{}', 4, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 5e Individual lines Expenditure & Utilisation */,
      ('04ad34b5-633d-5253-a857-b2ac1347e0dd', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '10c9cded-93ee-5c5c-9a97-1dea35bbeb60', 'Customisation of Tables', 'Thoughts', null, null, '', '', '{}', 5, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 5f Customisation of Tables */,
      ('718e517e-d921-542e-8a2d-2c0f0a4408bb', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', '10c9cded-93ee-5c5c-9a97-1dea35bbeb60', 'ServiceNow Error Issue', 'Developing', null, null, '', '', '{}', 6, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 5g ServiceNow Error Issue */,
      ('a131566e-778e-53f2-9545-c46efb3bbd15', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', null, 'Post Feedback Iterations', 'Thoughts', null, null, '', '', '{}', 5, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* Track 6 Post Feedback Iterations */,
      ('87554e79-f206-5410-bc4e-ff309b1c952c', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', 'a131566e-778e-53f2-9545-c46efb3bbd15', 'Email Notification', 'Planning', null, null, '', '', '{}', 0, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 6a Email Notification */,
      ('3a43d906-248d-5221-8317-3c371483fad2', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', 'a131566e-778e-53f2-9545-c46efb3bbd15', 'Force Refresh of Page', 'Developing', null, null, '', '', '{}', 1, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 6b Force Refresh of Page */,
      ('fe54e0ef-6604-5d9e-843b-18aa36ed5b0d', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', 'a131566e-778e-53f2-9545-c46efb3bbd15', 'Shift view for Reviewers and Approvals', 'Planning', null, null, '', '', '{}', 2, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 6c Shift view for Reviewers and Approvals */,
      ('579d4446-b702-555f-a3f3-2434cc0ae16e', 'b8b2de30-6920-5294-b86b-e5ef6bc8a41f', 'a131566e-778e-53f2-9545-c46efb3bbd15', 'Justification of Variance Link', 'Developing', null, null, '', '', '{}', 3, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 6d Justification of Variance Link */,
      -- POLARIS
      ('e77cf962-62f0-54d3-baf8-a530baa86745', '4b7a451d-a38d-5de3-93bd-a1bf5ab14ca0', null, 'Debt Management', 'Thoughts', null, null, '', '', '{}', 0, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* Track 1 Debt Management */,
      ('931e876b-1454-5e7f-a24a-47e45e5c4e1c', '4b7a451d-a38d-5de3-93bd-a1bf5ab14ca0', 'e77cf962-62f0-54d3-baf8-a530baa86745', 'Pulling of data on Debt Records', 'Thoughts', null, null, '', '', '{}', 0, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 1a Pulling of data on Debt Records */,
      ('be59deea-ff19-59c9-923e-b81c3fb6a706', '4b7a451d-a38d-5de3-93bd-a1bf5ab14ca0', 'e77cf962-62f0-54d3-baf8-a530baa86745', 'List of Debt Records', 'Thoughts', null, null, '', '', '{}', 1, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 1b List of Debt Records */,
      ('684c4a0c-7dd8-5a07-ba2d-3e9ee25bc8f3', '4b7a451d-a38d-5de3-93bd-a1bf5ab14ca0', 'be59deea-ff19-59c9-923e-b81c3fb6a706', 'List of Debt Records', 'Completed', null, null, '', '', '{}', 0, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 1b.1 List of Debt Records */,
      ('88985df0-c652-5c87-94f6-b6e0fb9cf1b6', '4b7a451d-a38d-5de3-93bd-a1bf5ab14ca0', 'be59deea-ff19-59c9-923e-b81c3fb6a706', 'Debtor Report', 'Completed', null, null, '', '', '{}', 1, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 1b.2 Debtor Report */,
      ('89b82631-ed46-5bd9-97a2-bbaacbe2b3b8', '4b7a451d-a38d-5de3-93bd-a1bf5ab14ca0', 'be59deea-ff19-59c9-923e-b81c3fb6a706', 'Arrears Report', 'Completed', null, null, '', '', '{}', 2, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 1b.3 Arrears Report */,
      ('5c811be4-fed8-5053-8a1d-74bc721f88c7', '4b7a451d-a38d-5de3-93bd-a1bf5ab14ca0', 'be59deea-ff19-59c9-923e-b81c3fb6a706', 'Written Off Report', 'Completed', null, null, '', '', '{}', 3, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 1b.4 Written Off Report */,
      ('63920449-7277-544d-9f1e-f035430124cd', '4b7a451d-a38d-5de3-93bd-a1bf5ab14ca0', 'be59deea-ff19-59c9-923e-b81c3fb6a706', 'To Be Written Off Report', 'Completed', null, null, '', '', '{}', 4, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 1b.5 To Be Written Off Report */,
      ('7ad3d98c-e4c1-55e4-af30-893933b50645', '4b7a451d-a38d-5de3-93bd-a1bf5ab14ca0', 'be59deea-ff19-59c9-923e-b81c3fb6a706', 'Call for Return', 'Completed', null, null, '', '', '{}', 5, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 1b.6 Call for Return */,
      ('c8c4df9e-9596-5bf2-829d-fd104a32f44c', '4b7a451d-a38d-5de3-93bd-a1bf5ab14ca0', 'e77cf962-62f0-54d3-baf8-a530baa86745', 'Payments', 'Thoughts', null, null, '', '', array['d971b8f4-e935-5ca6-8c85-da0c1b1d2c70']::uuid[], 2, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 1c Payments */,
      ('c92445c0-27c3-5176-bb93-cef61e59d91e', '4b7a451d-a38d-5de3-93bd-a1bf5ab14ca0', 'c8c4df9e-9596-5bf2-829d-fd104a32f44c', 'Monthly Giro deduction', 'Thoughts', null, null, '', '', '{}', 0, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 1c.1 Monthly Giro deduction */,
      ('6e21276d-e51d-5ea9-a8fb-9a2e20993ec4', '4b7a451d-a38d-5de3-93bd-a1bf5ab14ca0', 'e77cf962-62f0-54d3-baf8-a530baa86745', 'Reconciliation', 'Thoughts', null, null, '', '', '{}', 3, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 1d Reconciliation */,
      ('dbea7fa2-89f6-594c-8ca2-455f73290710', '4b7a451d-a38d-5de3-93bd-a1bf5ab14ca0', 'e77cf962-62f0-54d3-baf8-a530baa86745', 'Debt Management Dashboard', 'Thoughts', null, null, '', '', '{}', 4, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* 1e Debt Management Dashboard */,
      ('cc16b7b2-563a-5d7f-abfa-a093de63e7fa', '4b7a451d-a38d-5de3-93bd-a1bf5ab14ca0', null, 'Fees & Maintenance', 'Thoughts', null, null, '', '', '{}', 1, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* Track 2 Fees & Maintenance */,
      ('adebaa45-7826-595d-89db-9eb0f28fa2fb', '4b7a451d-a38d-5de3-93bd-a1bf5ab14ca0', null, 'Reconciliation', 'Thoughts', null, null, '', '', '{}', 2, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* Track 3 Reconciliation */,
      -- Payment Transformation
      ('76695065-5143-5c0e-ac58-36429dbdab83', 'd971b8f4-e935-5ca6-8c85-da0c1b1d2c70', null, 'Payment before Permit Approval', 'Pending User', null, null, '', '', '{}', 0, '2026-10-13T06:45:51.297Z', '2026-10-13T06:45:51.297Z') /* Track 1 Payment before Permit Approval */
    on conflict (id) do nothing;
  end if;
end;
$$;
