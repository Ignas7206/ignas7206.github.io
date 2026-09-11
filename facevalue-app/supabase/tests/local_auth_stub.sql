-- Stands in for what Supabase already provides. Tests only; never migrate this.
create schema if not exists auth;

create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls; end if;
end $$;

create or replace function assert(ok boolean, label text) returns void
language plpgsql as $$
begin
  if ok then raise notice 'PASS  %', label;
  else raise exception 'FAIL  %', label; end if;
end $$;
