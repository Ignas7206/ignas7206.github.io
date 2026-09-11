-- Face Value · functions
-- Anything that must read across the privacy boundary is security definer and
-- pinned to an explicit search_path.

-- Profile id of the caller. Security definer because policies on profiles
-- would otherwise need to read profiles to decide who you are.
create or replace function public.me() returns uuid
language sql stable security definer set search_path = public, pg_temp as $$
  select id from profiles where user_id = auth.uid()
$$;

-- Has the caller matched with this profile?
create or replace function public.is_matched(other uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from matches
    where (a_id = public.me() and b_id = other)
       or (b_id = public.me() and a_id = other)
  )
$$;

-- Is this profile in the caller's deck for today?
create or replace function public.in_todays_deck(card uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from daily_deck
    where user_id = auth.uid() and deck_date = current_date
      and card = any(card_ids)
  )
$$;

-- ------------------------------------------------------------- deck dealing
-- Scores the pool for one person and deals at most 16 cards. Never returns
-- anyone already swiped, blocked in either direction, or the caller.
create or replace function public.deal_deck(p_user uuid, p_size int default 16)
returns uuid[]
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  mine  profiles;
  ids   uuid[];
begin
  select * into mine from profiles where user_id = p_user;
  if mine.id is null then
    raise exception 'no profile for user %', p_user;
  end if;

  select array_agg(c.id order by c.score desc, c.id)
    into ids
  from (
    select p.id,
           coalesce((select max(weight) from fit_rules
                     where want_id = mine.want and offer_id = p."offer"), 0) * 3
         + coalesce((select max(weight) from fit_rules
                     where want_id = p.want and offer_id = mine."offer"), 0) * 2
         + case when p.industry = mine.industry then 2 else 0 end
           as score
    from profiles p
    where p.state = 'active'
      and p.id <> mine.id
      and p.metro = mine.metro
      and p.vertical = mine.vertical
      and not exists (select 1 from swipes s
                      where s.swiper_id = mine.id and s.target_id = p.id)
      and not exists (select 1 from blocks b
                      where (b.blocker_id = mine.id and b.blocked_id = p.id)
                         or (b.blocker_id = p.id and b.blocked_id = mine.id))
    order by score desc, p.created_at
    limit p_size
  ) c;

  ids := coalesce(ids, '{}'::uuid[]);

  insert into daily_deck (user_id, deck_date, card_ids)
  values (p_user, current_date, ids)
  on conflict (user_id, deck_date) do update set card_ids = excluded.card_ids;

  return ids;
end $$;

-- --------------------------------------------------------- match on reciprocity
-- A match is created by the database the moment the second trade lands, so two
-- simultaneous swipes cannot produce two matches or none.
create or replace function public.on_swipe() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  m_id uuid;
  lo   uuid;
  hi   uuid;
begin
  if new.direction <> 'trade' then
    return new;
  end if;

  if not exists (select 1 from swipes
                 where swiper_id = new.target_id
                   and target_id = new.swiper_id
                   and direction = 'trade') then
    return new;
  end if;

  lo := least(new.swiper_id, new.target_id);
  hi := greatest(new.swiper_id, new.target_id);

  insert into matches (a_id, b_id) values (lo, hi)
  on conflict (a_id, b_id) do nothing
  returning id into m_id;

  if m_id is null then
    select id into m_id from matches where a_id = lo and b_id = hi;
  end if;

  insert into threads (match_id) values (m_id) on conflict (match_id) do nothing;
  return new;
end $$;

create trigger swipes_match_trg
  after insert on swipes
  for each row execute function public.on_swipe();

-- ------------------------------------------------------------ signing a card
-- Accepting a meeting is what signs the card. Only the other side can accept.
create or replace function public.accept_meeting(p_meeting uuid) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  mt meetings;
begin
  select * into mt from meetings where id = p_meeting;
  if mt.id is null then
    raise exception 'no such meeting';
  end if;
  if mt.proposed_by = public.me() then
    raise exception 'the other side accepts, not the proposer';
  end if;
  if not exists (
    select 1 from threads t join matches m on m.id = t.match_id
    where t.id = mt.thread_id and (m.a_id = public.me() or m.b_id = public.me())
  ) then
    raise exception 'not your thread';
  end if;

  update meetings
     set status = 'accepted', confirmed_at = now()
   where id = p_meeting;
end $$;

-- A card counts toward a series only once a meeting on it is accepted.
-- security_invoker so the caller's own policies apply through the view too:
-- without it a view owned by a superuser quietly bypasses every policy below.
create or replace view signed_cards with (security_invoker = true) as
  select m.id as match_id,
         case when m.a_id = public.me() then m.b_id else m.a_id end as profile_id,
         min(mt.confirmed_at) as signed_at
  from matches m
  join threads t  on t.match_id = m.id
  join meetings mt on mt.thread_id = t.id
  where (m.a_id = public.me() or m.b_id = public.me())
    and mt.status in ('accepted','met')
  group by m.id, profile_id;
