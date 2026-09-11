# Face Value — data layer

The database, its policies, and a suite that tries to break them.

Built first on purpose: the product promise is that a name is unreadable until
both sides trade, and a promise like that has to live in the database. Hiding a
field in the UI is one devtools tab away from being no promise at all.

```
supabase/
  migrations/
    0001_schema.sql      tables. identities is deliberately its own table
    0002_functions.sql   deck dealing, the match trigger, signing a card
    0003_policies.sql    row level security — the product promise, enforced
  tests/
    local_auth_stub.sql  stands in for what Supabase already provides
    rls_test.sql         20 checks, run as the `authenticated` role
    run.sh               applies every migration to a throwaway db, runs them
```

## Running the tests

Against a local Postgres 16:

```bash
cd supabase/tests && ./run.sh
```

It drops and recreates `facevalue_test`, applies every migration in order, then
runs the suite as `authenticated` — the same role a phone connects with. Any
failure aborts with a non-zero exit, so this belongs in CI before every deploy.

Current state: **20 passing.** Among them —

- the pool is invisible: only your own card, today's dealt cards, and people
  you matched with are readable at all
- no identity is readable before a match, and every identity is readable the
  moment one exists
- you cannot see who swiped on you
- a swipe attributed to someone else is refused by the database
- one right swipe is not a match; reciprocity creates exactly one, and opens
  the thread itself
- messages and threads you are not part of do not exist to you
- a blocked profile is never dealt again
- the proposer cannot accept their own meeting invite
- a traded card is not signed until the meeting is accepted

## Applying it to Supabase

```bash
supabase link --project-ref <ref>
supabase db push
```

Do **not** apply `tests/local_auth_stub.sql` — Supabase already provides
`auth.uid()` and the `anon` / `authenticated` / `service_role` roles. The stub
exists only so the same migrations can be tested against a bare Postgres.

`0001_schema.sql` adds the foreign key from `profiles.user_id` to `auth.users`
only when that table exists, so account deletion cascades in production and the
migration still runs in tests.

## Design notes worth keeping

**`identities` is a separate table, not columns on `profiles`.** A careless
`select *` on a profile can then never leak a name. The policy on it is the
single most important line in the repo.

**The deck is dealt by the server.** `deal_deck()` returns at most 16 ids for
one day and stores them; the client never receives the pool. That is the
privacy boundary and the scarcity mechanic in one function.

**Matching is a trigger, not application code.** Two simultaneous right swipes
cannot produce two matches or none, and `check (a_id < b_id)` makes a duplicate
pair impossible rather than merely unlikely.

**`fit_rules` is a table.** What a given "want" is satisfied by is data, so the
scoring can be tuned from real match rates without a deploy.

**Block and report exist in the first migration.** Apple requires both for any
app with user content and messaging, and retrofitting safety is how you end up
rejected a week before a launch event.

## What is not here yet

The web app: onboarding, the deck, threads, and the meeting flow, against these
tables. The working prototype it is being ported from lives in `../facevalue/`.
