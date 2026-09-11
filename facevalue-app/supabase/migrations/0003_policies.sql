-- Face Value · row level security
-- These policies are the product promise, expressed where it cannot be bypassed.
-- If you change one, change tests/rls_test.sql in the same commit.

alter table profiles   enable row level security;
alter table identities enable row level security;
alter table daily_deck enable row level security;
alter table swipes     enable row level security;
alter table matches    enable row level security;
alter table threads    enable row level security;
alter table messages   enable row level security;
alter table meetings   enable row level security;
alter table blocks     enable row level security;
alter table reports    enable row level security;
alter table fit_rules  enable row level security;

grant usage on schema public to authenticated;
grant select on profiles, identities, daily_deck, matches, threads,
                messages, meetings, fit_rules, swipes, blocks to authenticated;
grant select on signed_cards to authenticated;
grant insert on swipes, messages, meetings, blocks, reports to authenticated;
grant update on profiles to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- ------------------------------------------------------------------ profiles
-- You see your own card, the cards dealt to you today, and anyone you matched
-- with. Nothing else in the pool exists as far as the client is concerned.
create policy profiles_visible on profiles for select to authenticated
  using (
    user_id = auth.uid()
    or public.in_todays_deck(id)
    or public.is_matched(id)
  );

create policy profiles_own_update on profiles for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------- identities
-- The one that matters. A name is readable only when a match row exists.
create policy identities_after_match on identities for select to authenticated
  using (
    profile_id = public.me()
    or public.is_matched(profile_id)
  );

-- ---------------------------------------------------------------- daily deck
create policy deck_own on daily_deck for select to authenticated
  using (user_id = auth.uid());

-- -------------------------------------------------------------------- swipes
-- You can read your own swipes and cast new ones. You can never read who
-- swiped on you: that would leak intent before reciprocity.
create policy swipes_own on swipes for select to authenticated
  using (swiper_id = public.me());

create policy swipes_insert on swipes for insert to authenticated
  with check (
    swiper_id = public.me()
    and public.in_todays_deck(target_id)
    and not exists (select 1 from blocks b
                    where (b.blocker_id = public.me() and b.blocked_id = target_id)
                       or (b.blocker_id = target_id and b.blocked_id = public.me()))
  );

-- ------------------------------------------------------------------- matches
create policy matches_own on matches for select to authenticated
  using (a_id = public.me() or b_id = public.me());

create policy threads_own on threads for select to authenticated
  using (exists (select 1 from matches m
                 where m.id = threads.match_id
                   and (m.a_id = public.me() or m.b_id = public.me())));

-- ------------------------------------------------------------------ messages
create policy messages_own_threads on messages for select to authenticated
  using (exists (select 1 from threads t join matches m on m.id = t.match_id
                 where t.id = messages.thread_id
                   and (m.a_id = public.me() or m.b_id = public.me())));

create policy messages_send on messages for insert to authenticated
  with check (
    sender_id = public.me()
    and exists (select 1 from threads t join matches m on m.id = t.match_id
                where t.id = thread_id
                  and (m.a_id = public.me() or m.b_id = public.me()))
  );

-- ------------------------------------------------------------------ meetings
create policy meetings_own_threads on meetings for select to authenticated
  using (exists (select 1 from threads t join matches m on m.id = t.match_id
                 where t.id = meetings.thread_id
                   and (m.a_id = public.me() or m.b_id = public.me())));

create policy meetings_propose on meetings for insert to authenticated
  with check (
    proposed_by = public.me()
    and exists (select 1 from threads t join matches m on m.id = t.match_id
                where t.id = thread_id
                  and (m.a_id = public.me() or m.b_id = public.me()))
  );

-- -------------------------------------------------------------------- safety
create policy blocks_own on blocks for select to authenticated
  using (blocker_id = public.me());
create policy blocks_insert on blocks for insert to authenticated
  with check (blocker_id = public.me());

-- Reports are write-only from the client. Nobody reads their own report back,
-- and nobody reads anyone else's.
create policy reports_insert on reports for insert to authenticated
  with check (reporter_id = public.me());

create policy fit_rules_read on fit_rules for select to authenticated using (true);
