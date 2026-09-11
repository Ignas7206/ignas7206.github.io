# Face Value — techninis stackas ir paleidimo checklist

Ką reikia pastatyti, kur laikomi duomenys, kaip veikia prisijungimai ir kokie
„oficialūs" dalykai privalomi prieš paleidžiant JAV rinkoje.

Paskutinis atnaujinimas: 2026-09.

---

## 0. Vienas sprendimas, kuris gali nužudyti produktą

Visas produkto pažadas — **tapatybė paslėpta, kol nėra abipusio match'o.**

Jei serveris atsiunčia klientui pilną profilio įrašą su `full_name` ir
`photo_url`, o programėlė tiesiog jį paslepia CSS'u — bet kas atidaro naršyklės
devtools arba perima tinklo užklausą ir pamato viską. Produkto nebėra, o kartu
ir duomenų nutekėjimo incidentas.

**Taisyklė: tapatybė niekada neišeina iš serverio, kol nėra match'o eilutės
duomenų bazėje.** Tai reiškia dvi atskiras lenteles ir DB lygio taisyklę, ne
`if` sakinį programėlėje. Žr. 2 ir 3 skyrius.

---

## 1. Kur kaupiama duomenų bazė

**Rekomendacija: Supabase** (valdomas Postgres).

| Kodėl | |
|---|---|
| Postgres | Modelis reliacinis — žmonės, swipe'ai, match'ai, žinutės, susitikimai. Tai lentelės, ne dokumentai. |
| Row Level Security | Kas ką mato, aprašoma **duomenų bazėje**. Būtent tai apsaugo paslėptą tapatybę. |
| Auth įskaičiuotas | Magic link, OTP, Apple/Google — nereikia statyti savo. |
| Realtime | Pokalbiai per WebSocket be atskiro serviso. |
| Storage | Nuotraukoms, kai jos atsiranda po match'o. |
| Kaina | Nemokamas tieras → $25/mėn. Pro. 400 vartotojų telpa su atsarga. |

**Regionas: `us-east-1`.** Duomenys apie JAV verslus turi gulėti JAV — tai
supaprastina pokalbį su kiekvienu pirkėju ir kiekvienu teisininku.

**Kodėl ne Firebase:** realtime pokalbiams jis geras, bet suvedimo užklausos
(rask man 16 kortelių pagal miestą, vertikalę, ką žmogus nori ir ko dar
nemačiau) yra reliacinės. Firestore jas paverčia skausmu, o saugumo taisyklės
tampa sunkiau audituojamos nei RLS politikos.

**Kodėl ne savo Postgres ant VPS:** galima, bet tada tu pats darai backup'us,
rotuoji raktus, prižiūri auth. Pirmus metus tai ne tavo darbas.

---

## 2. Duomenų modelis

```sql
-- Supabase valdo auth.users

profiles          -- id, user_id, metro, vertical, archetype, industry,
                  -- want, offer, truth, alias, role_line, status, created_at
identities        -- profile_id, full_name, company, photo_path, linkedin_url,
                  -- verified_at            ← NIEKADA nepasiekiama viešai
cards             -- VIEW virš profiles: tik tai, ką rodo denis

daily_deck        -- user_id, date, card_ids[]   ← generuoja serveris
swipes            -- swiper_id, target_id, direction, created_at (unikali pora)
matches           -- a_id, b_id, created_at      ← sukuria triggeris
threads           -- match_id
messages          -- thread_id, sender_id, body, created_at
meetings          -- thread_id, kind, slot_at, status, confirmed_at

blocks            -- blocker_id, blocked_id
reports           -- reporter_id, target_id, reason, created_at
```

Du dalykai, kurie čia nėra atsitiktiniai:

**`identities` atskirai nuo `profiles`.** Ne stulpelis, o atskira lentelė su
sava taisykle. Taip fizikai neįmanoma netyčia grąžinti vardo per `select *`.

**`daily_deck` generuoja serveris.** Klientas niekada negauna viso pool'o —
gauna 16 ID vienai dienai. Tai vienu metu ir privatumas, ir ta scarcity
mechanika, kuri laiko retention.

---

## 3. RLS politikos (esmė)

```sql
-- kortelę matai, jei ji šiandien tavo denyje arba jūs jau match'inti
create policy "cards visible" on profiles for select using (
  id in (select unnest(card_ids) from daily_deck
         where user_id = auth.uid() and date = current_date)
  or exists (select 1 from matches m
             where (m.a_id = auth.uid() and m.b_id = profiles.id)
                or (m.b_id = auth.uid() and m.a_id = profiles.id))
);

-- tapatybė matoma TIK po match'o
create policy "identity after match" on identities for select using (
  exists (select 1 from matches m
          where (m.a_id = auth.uid() and m.b_id = identities.profile_id)
             or (m.b_id = auth.uid() and m.a_id = identities.profile_id))
);

-- žinutes matai tik savo gijose
create policy "own threads" on messages for select using (
  thread_id in (select t.id from threads t join matches m on m.id = t.match_id
                where m.a_id = auth.uid() or m.b_id = auth.uid())
);
```

Šitas tris politikas reikia parašyti **pirma**, prieš bet kokį UI. Ir jas
reikia turėti testuose — po kiekvieno deploy'aus automatinis testas, kuris
bando nuskaityti svetimą `identities` eilutę ir tikisi tuščio rezultato.

---

## 4. Prisijungimai — ar jų reikia?

**Reikia, bet ne iš karto.**

Kodėl reikia: match'ai, pokalbiai ir kolekcija turi išlikti pakeitus telefoną.
Ir be tapatybės neįmanoma užtikrinti taisyklės „vienas žmogus — viena kortelė",
o tai yra visas anti-spam pagrindas.

Kodėl ne iš karto: parodoje žmogus nuskenuoja QR kodą. Jei pirmas ekranas yra
registracija, prarandi jį per 3 sekundes.

**Srautas:**

1. Nuskenavo QR → iš karto atsakinėja 5 klausimus → mato denį. Viskas
   `localStorage`, jokio konto.
2. **Pirmas swipe į dešinę** → „Kad jie galėtų tau atsakyti, reikia, kur
   pasiekti." → įveda el. paštą, gauna 6 skaitmenų kodą.
3. Konto sukūrimas perkelia vietinę būseną į serverį.

**Metodas: magic link / OTP kodas į el. paštą.** Ne slaptažodis — jis tik
prideda „pamiršau slaptažodį" srautą ir saugumo skolą.

SMS OTP atrodo patogiau, bet JAV tam reikia A2P 10DLC registracijos (brand +
campaign per Twilio, ~$4 vienkartinis + ~$10/mėn., patvirtinimas nuo kelių
dienų iki savaičių). Verta, bet ne pirmą savaitę.

**Apple/Google prisijungimai:** neprivalomi. Bet **jei įdėsi bent vieną
trečios šalies prisijungimą į iOS programėlę, Apple reikalauja kartu
pasiūlyti ir „Sign in with Apple".** Paprasčiausias kelias — leisti tik el.
paštą, kol nėra native app'o.

---

## 5. Kas dar statoma

| Sluoksnis | Sprendimas | Kaina |
|---|---|---|
| Web app | Next.js ant Vercel | $0 → $20/mėn. |
| Native (vėliau) | Expo / React Native, tas pats kodas | $0 |
| Duomenys + auth | Supabase | $0 → $25/mėn. |
| Transakciniai laiškai | Resend arba Postmark | $0 → $20/mėn. |
| Push | Expo Push (FCM + APNs) | $0 |
| Analitika | PostHog — piltuvėlis yra produkto metrika | $0 → $30/mėn. |
| Klaidos | Sentry | $0 → $26/mėn. |
| Mokėjimai (vėliau) | Stripe | 2,9% + $0,30 |
| Domenas + paštas | Namecheap + Google Workspace | ~$80/metus |

**Iš viso paleidžiant: ~$50–100/mėn.** Iki kelių tūkstančių vartotojų
nepasikeis reikšmingai.

Laiškams būtinai sutvarkyk **SPF, DKIM ir DMARC** pirmą dieną. Be to prisijungimo
kodai nueis į spam'ą, ir tu galvosi, kad produktas neįdomus.

---

## 6. Oficialūs dalykai JAV rinkai

### Juridinis
- **US juridinis asmuo.** Delaware C-Corp, jei planuoji pritraukti investicijų;
  LLC, jei ne. Stripe Atlas ~$500, padaro per savaitę.
- **EIN** (mokesčių numeris) — reikalingas bankui ir Stripe.
- **Registered agent** — ~$100/metus.

### Privalomi dokumentai
- **Privacy Policy** ir **Terms of Service** — be jų neįleis nei Apple, nei
  Google. Termly ar Iubenda ~$15–30/mėn., arba teisininkas $1 500–3 000.
- **CCPA/CPRA atitiktis** (Kalifornija + ~20 kitų valstijų): „Do Not Sell or
  Share" nuoroda, duomenų ištrynimo srautas, duomenų eksportas.
- **18+ amžiaus ribojimas** registracijoje. Su nepilnamečiais atsiranda COPPA,
  o ten tu nenori būti.
- **TCPA**: prisijungimo SMS yra transakcinė ir paprastai leidžiama. Bet bet
  koks rinkodarinis SMS reikalauja aiškaus rašytinio sutikimo. Baudos
  $500–1 500 **už vieną žinutę** — tai vienintelis dalykas šitame sąraše, kuris
  gali sunaikinti įmonę.

### App Store / Google Play
- **Apple Developer $99/metus**, **Google Play $25 vienkartinis.**
- Apple reikalauja **paskyros ištrynimo pačioje programėlėje**, ne per laišką.
- Programėlėms su vartotojų turiniu ir pokalbiais Apple reikalauja: turinio
  filtravimo, **pranešimo apie pažeidimą mechanizmo**, **galimybės užblokuoti**
  vartotoją, viešo kontakto ir reagavimo per 24 valandas. Todėl `blocks` ir
  `reports` lentelės yra modelyje nuo pradžių, ne „vėliau".
- **Privacy nutrition labels** (Apple) ir **Data Safety** forma (Google) —
  abi reikalauja tiksliai išvardyti, ką renki.
- Amžiaus reitingas greičiausiai 17+.

### Mokėjimai — svarbi smulkmena
Jei prenumeratą parduodi **iOS programėlėje**, Apple paprastai reikalauja
naudoti savo pirkimus ir pasiima 15–30%. Jei parduodi **web'e per Stripe** —
ne. JAV taisyklės dėl nuorodų į išorinį mokėjimą pastaruoju metu kito, tad
prieš darant patikrink dabartinę redakciją, bet numatytoji strategija:
**prenumerata perkama naršyklėje, programėlė tik atrakina.**

---

## 7. Eiliškumas

1. Supabase projektas, schema, **trys RLS politikos ir testai joms**
2. Web app (Next.js): 5 klausimai → denis → swipe → match
3. Auth pirmame dešiniame swipe (el. pašto OTP)
4. Gijos ir žinutės (realtime)
5. Susitikimai ir Signed būsena
6. Blokavimas, pranešimai apie pažeidimus, paskyros ištrynimas
7. Privacy Policy, ToS, juridinis asmuo
8. PostHog piltuvėlis — be jo nežinosi, ar veikia
9. Tik tada native app'as ir parduotuvės

**1–5 punktai su vienu full-stack inžinieriumi: 6–10 savaičių.**
Iki 9 punkto: realiai pusmetis.

Parodoje mobili web versija veikia iš QR kodo be jokio parsisiuntimo —
pirmam paleidimui native programėlės **nereikia**.
