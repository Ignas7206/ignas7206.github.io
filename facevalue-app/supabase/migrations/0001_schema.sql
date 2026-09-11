-- Face Value · schema
-- Identity is deliberately NOT a column on profiles. It lives in its own table
-- so that a careless `select *` can never leak a name. See 0003_policies.sql.

create extension if not exists pgcrypto;

create type swipe_dir      as enum ('pass','trade');
create type meeting_status as enum ('proposed','accepted','met','cancelled');
create type profile_state  as enum ('active','paused','removed');

-- ---------------------------------------------------------------- profiles
-- Everything on a card. Answers are stored as option ids, not prose: ids are
-- what the matching scores on, and the wording can change without a migration.
-- alias/role_line are denormalised so the deck renders without the copy table.
create table profiles (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null unique,
  metro       text not null,
  vertical    text not null,
  archetype   text not null check (archetype in ('F','O','C','M','X')),
  industry    text not null,
  want        text not null,
  "offer"     text not null,
  truth       text not null,
  alias       text not null,
  role_line   text not null,
  rarity      text not null default 'common'
              check (rarity in ('common','uncommon','rare','legendary')),
  state       profile_state not null default 'active',
  created_at  timestamptz not null default now()
);
create index profiles_pool_idx on profiles (metro, vertical) where state = 'active';

-- ---------------------------------------------------------------- identities
-- Readable only after a match. Never join this into a deck query.
create table identities (
  profile_id   uuid primary key references profiles(id) on delete cascade,
  full_name    text not null,
  company      text,
  email        text not null,
  photo_path   text,
  linkedin_url text,
  verified_at  timestamptz
);

-- ---------------------------------------------------------------- fit rules
-- What a given "want" is satisfied by. Data, not code, so it can be tuned
-- without a deploy once real match rates come in.
create table fit_rules (
  want_id  text not null,
  offer_id text not null,
  weight   int  not null default 1,
  primary key (want_id, offer_id)
);

insert into fit_rules (want_id, offer_id, weight) values
  ('customers','room',3), ('customers','intros',3),
  ('cofounder','hands',3), ('cofounder','scars',2),
  ('capital','money',4),
  ('hires','intros',3),    ('hires','room',2),
  ('advice','scars',3),    ('advice','numbers',3),
  ('peers','scars',2),     ('peers','room',2), ('peers','intros',1);

-- ---------------------------------------------------------------- the deck
-- Server-generated, 16 ids a day. The client never receives the pool: that is
-- both the privacy boundary and the scarcity mechanic.
create table daily_deck (
  user_id   uuid not null,
  deck_date date not null default current_date,
  card_ids  uuid[] not null,
  primary key (user_id, deck_date)
);

-- ---------------------------------------------------------------- swipes
create table swipes (
  id         bigserial primary key,
  swiper_id  uuid not null references profiles(id) on delete cascade,
  target_id  uuid not null references profiles(id) on delete cascade,
  direction  swipe_dir not null,
  created_at timestamptz not null default now(),
  unique (swiper_id, target_id),
  check (swiper_id <> target_id)
);
create index swipes_target_idx on swipes (target_id, direction);

-- ---------------------------------------------------------------- matches
-- a_id < b_id keeps one canonical row per pair, so a duplicate is impossible
-- rather than merely unlikely.
create table matches (
  id         uuid primary key default gen_random_uuid(),
  a_id       uuid not null references profiles(id) on delete cascade,
  b_id       uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (a_id < b_id),
  unique (a_id, b_id)
);

create table threads (
  id         uuid primary key default gen_random_uuid(),
  match_id   uuid not null unique references matches(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table messages (
  id         bigserial primary key,
  thread_id  uuid not null references threads(id) on delete cascade,
  sender_id  uuid not null references profiles(id) on delete cascade,
  body       text not null check (length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index messages_thread_idx on messages (thread_id, created_at);

-- A card is only *signed* once a meeting is accepted. Trading is not collecting.
create table meetings (
  id           uuid primary key default gen_random_uuid(),
  thread_id    uuid not null references threads(id) on delete cascade,
  proposed_by  uuid not null references profiles(id) on delete cascade,
  kind         text not null check (kind in ('call','coffee','event')),
  slot_at      timestamptz not null,
  status       meeting_status not null default 'proposed',
  confirmed_at timestamptz
);
create index meetings_thread_idx on meetings (thread_id);

-- ---------------------------------------------------------- safety (day one)
-- Apple requires block + report for any app with user content and messaging,
-- so these are in the first migration, not a later one.
create table blocks (
  blocker_id uuid not null references profiles(id) on delete cascade,
  blocked_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table reports (
  id          bigserial primary key,
  reporter_id uuid not null references profiles(id) on delete cascade,
  target_id   uuid not null references profiles(id) on delete cascade,
  reason      text not null,
  detail      text,
  created_at  timestamptz not null default now(),
  handled_at  timestamptz
);

-- Account deletion cascades from auth.users. Added conditionally so the same
-- migration runs against a bare Postgres in tests and against Supabase in prod.
do $$
begin
  if exists (select 1 from information_schema.tables
             where table_schema = 'auth' and table_name = 'users') then
    alter table profiles
      add constraint profiles_user_fk
      foreign key (user_id) references auth.users(id) on delete cascade;
  end if;
end $$;
