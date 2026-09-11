-- Face Value · does the privacy boundary actually hold?
-- Every check below runs as the `authenticated` role, the way a phone does.
\set ON_ERROR_STOP on
\set QUIET on
set client_min_messages = notice;

reset role;

\set A '\'00000000-0000-0000-0000-0000000000a1\''
\set B '\'00000000-0000-0000-0000-0000000000b1\''
\set C '\'00000000-0000-0000-0000-0000000000c1\''
\set D '\'00000000-0000-0000-0000-0000000000d1\''
\set E '\'00000000-0000-0000-0000-0000000000e1\''
\set UA '\'00000000-0000-0000-0000-0000000000a0\''
\set UB '\'00000000-0000-0000-0000-0000000000b0\''
\set UC '\'00000000-0000-0000-0000-0000000000c0\''

truncate profiles cascade;
truncate daily_deck;

insert into profiles (id,user_id,metro,vertical,archetype,industry,want,"offer",truth,alias,role_line,rarity) values
 (:A,:UA,'Chicago','Manufacturing','F','Manufacturing','customers','intros','t1','The Owner-Operator','Building something of my own','common'),
 (:B,:UB,'Chicago','Manufacturing','X','Manufacturing','advice','room','t2','The Connector','Knowing who to call','rare'),
 (:C,:UC,'Chicago','Manufacturing','C','Software','capital','money','t3','The Check Writer','Deciding where money goes','legendary'),
 (:D,'00000000-0000-0000-0000-0000000000d0','Chicago','Manufacturing','M','Logistics','peers','scars','t4','The Builder','Making the actual thing','common'),
 (:E,'00000000-0000-0000-0000-0000000000e0','Chicago','Manufacturing','O','Manufacturing','hires','numbers','t5','The Fixer','Running the machine','common');

insert into identities (profile_id, full_name, company, email) values
 (:A,'Ignas Malinauskas','Northvale','a@example.com'),
 (:B,'Rosa Villanueva','Assoc','b@example.com'),
 (:C,'Margaret Oyelowo','Family Office','c@example.com'),
 (:D,'Marcus Oyelaran','Shop','d@example.com'),
 (:E,'Dana Whitfield','Ridgeway','e@example.com');

-- A has blocked E: E must never be dealt to A again.
insert into blocks (blocker_id, blocked_id) values (:A,:E);

select deal_deck(:UA, 2);

-- ========================================================= as A
set role authenticated;
select set_config('request.jwt.claim.sub', :UA, false);

select assert(public.me() = :A, 'me() resolves the caller''s profile');

select assert(
  (select cardinality(card_ids) from daily_deck where user_id = :UA) = 2,
  'deck is dealt at the requested size, not the whole pool');

select assert(
  not exists (select 1 from daily_deck
              where user_id = :UA and :E = any(card_ids)),
  'a blocked profile is never dealt');

select assert(
  (select count(*) from profiles) = 3,
  'pool is invisible: only self plus the two dealt cards are readable');

select assert(
  (select count(*) from profiles where id = :E) = 0,
  'an undealt, blocked profile does not exist to the client');

-- THE one that matters
select assert(
  (select count(*) from identities where profile_id <> :A) = 0,
  'no identity is readable before a match');

select assert(
  (select full_name from identities where profile_id = :A) = 'Ignas Malinauskas',
  'you can always read your own identity');

-- Intent never leaks before reciprocity.
reset role;
insert into swipes (swiper_id, target_id, direction) values (:C,:A,'trade');
set role authenticated;
select set_config('request.jwt.claim.sub', :UA, false);

select assert(
  (select count(*) from swipes) = 0,
  'you cannot see who swiped on you');

-- Spoofing another person's swipe must be refused by the database.
do $$
begin
  begin
    insert into swipes (swiper_id, target_id, direction)
    values ('00000000-0000-0000-0000-0000000000b1',
            '00000000-0000-0000-0000-0000000000d1','trade');
    raise exception 'FAIL  a swipe attributed to someone else was accepted';
  exception when insufficient_privilege then
    raise notice 'PASS  a swipe attributed to someone else is refused';
  end;
end $$;

-- ========================================================= the match
reset role;
select deal_deck(:UA);
select deal_deck(:UB);

set role authenticated;
select set_config('request.jwt.claim.sub', :UA, false);
insert into swipes (swiper_id, target_id, direction) values (:A,:B,'trade');

select assert((select count(*) from matches) = 0,
  'one right swipe is not a match');

select set_config('request.jwt.claim.sub', :UB, false);
insert into swipes (swiper_id, target_id, direction) values (:B,:A,'trade');

select assert((select count(*) from matches) = 1,
  'reciprocity creates exactly one match');
select assert((select count(*) from threads) = 1,
  'the thread is opened by the database, not the client');

select set_config('request.jwt.claim.sub', :UA, false);
select assert(
  (select full_name from identities where profile_id = :B) = 'Rosa Villanueva',
  'the name is readable the moment the match exists');
select assert(
  (select count(*) from identities where profile_id = :C) = 0,
  'and still hidden for everyone else');

-- ========================================================= messages
insert into messages (thread_id, sender_id, body)
  values ((select id from threads limit 1), :A, 'no pitch, twenty minutes?');

select set_config('request.jwt.claim.sub', :UC, false);
select assert((select count(*) from messages) = 0,
  'messages in a thread you are not in are unreadable');
select assert((select count(*) from threads) = 0,
  'so is the thread itself');

-- ========================================================= signing the card
select set_config('request.jwt.claim.sub', :UA, false);
insert into meetings (thread_id, proposed_by, kind, slot_at)
  values ((select id from threads limit 1), :A, 'coffee', now() + interval '2 days');

do $$
begin
  begin
    perform accept_meeting((select id from meetings limit 1));
    raise exception 'FAIL  the proposer was allowed to accept their own invite';
  exception when raise_exception then
    if position('FAIL' in sqlerrm) > 0 then raise; end if;
    raise notice 'PASS  the proposer cannot accept their own invite';
  end;
end $$;

select assert((select count(*) from signed_cards) = 0,
  'a traded card is not signed yet');

select set_config('request.jwt.claim.sub', :UB, false);
select accept_meeting((select id from meetings limit 1));

select set_config('request.jwt.claim.sub', :UA, false);
select assert((select count(*) from signed_cards) = 1,
  'accepting the meeting is what signs the card');

reset role;
\echo ''
\echo 'All row level security checks passed.'
