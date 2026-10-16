-- =====================================================================
-- Project AHA tracker: Scorecard (North Star + OKRs)
-- Run once in the Supabase SQL Editor. Safe to run more than once.
-- Adds:
--   initiatives.north_star   the initiative's North Star statement
--   okrs                     key results with baseline and target
--   okr_results              each measured result over time (for the charts)
-- Same access rules as the rest of the tracker: any signed-in user reads,
-- only emails in the editors table can add, change or delete.
-- =====================================================================

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
