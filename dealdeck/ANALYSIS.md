# Deal Deck — B2B „Tinder" JAV rinkai

Analizė, prielaidos ir prototipo pagrindimas. Paskutinis atnaujinimas: 2026-09.

---

## 1. Kodėl beveik visi ankstesni bandymai žlugo

Swipe mechanika profesiniam tinklui bandyta ne kartą, ir beveik visi žinomi bandymai baigėsi tuo pačiu:

| Produktas | Statusas | Kodėl nepavyko |
|---|---|---|
| **Shapr** | uždarytas 2023 | „Pažintys dėl pažinčių" — vertė buvo neapibrėžta, retention krito po 2–3 savaičių |
| **Bumble Bizz** | uždarytas 2025 | Dating UX perkeltas į verslo kontekstą be verslo tikslo; auditorija persidengė su LinkedIn |
| **Ripple** (Match Group) | uždarytas | Tas pats — networking be sandorio |
| **Lunchclub** | veikia | Pakeitė modelį: nebe swipe, o AI parenkami 1:1 skambučiai |

**Pagrindinė pamoka:** žmonės nesvipina dėl „naujų pažinčių". Jie svipina, kai kitoje pusėje yra **konkretus, laike apibrėžtas poreikis su pinigais**. Swipe yra tinkama sąsaja *filtravimui*, bet ne tinklaveikai.

Iš to seka produkto tezė:

> Ne „Tinder verslo žmonėms", o **paklausos ir pasiūlos suvedimas su swipe kaip filtravimo sąsaja**. Kortelėje matomas ne žmogus — matomas **sandoris**: ko reikia, už kiek, per kiek laiko.

---

## 2. Rinka (JAV)

- ~33 mln. registruotų verslų, iš jų ~6 mln. su samdomais darbuotojais. Taikinys — **20–500 darbuotojų** segmentas: per didelis Google Ads „pasisektų-nepasisektų" pardavimams, per mažas enterprise procurement platformoms (Ariba, Coupa).
- Šio segmento skausmas yra ne „nepažįstu žmonių", o **cold outreach nustojo veikti**: atsakymų rodikliai į šaltus el. laiškus nukritę žemiau 2%, LinkedIn InMail prisotintas.
- Egzistuojanti alternatyva yra brokeriai, prekybos asociacijos, parodos ir rekomendacijos — brangu ir lėta.

**TAM/SAM greitas skaičiavimas (konservatyvus):**
- SAM: ~600 tūkst. įmonių 20–500 darbuotojų segmente, aktyviai perkančių ar parduodančių B2B.
- Realus pasiekiamumas per 3 metus: 1–2% → 6–12 tūkst. mokančių sąskaitų.
- Prie $300/mėn. vidutinio čekio → $22–43 mln. ARR. Tai pakankamai didelis rinkos langas VC raundui, bet tik jei išsprendžiamas likvidumo klausimas (žr. 4 sk.).

---

## 3. Kas kortelėje (ir kodėl būtent tai)

Prototipe kiekviena kortelė rodo tik tai, kas leidžia priimti sprendimą per 3 sekundes:

- **Intent** — Buying / Selling / Partnering / Investing. Be šito nėra suvedimo logikos.
- **„Looking for"** — viena konkreti eilutė. Ne „ieškome partnerysčių", o „telemetrijos atnaujinimas 40 priekabų iki Q1 audito".
- **Deal band ir cycle** — $80K–$400K, 60 dienų. Tai filtruoja 80% netinkamų pokalbių.
- **Verifikacijos ženklai** — D-U-N-S, SOC 2, HIPAA BAA, bonded, FMCSA authority, Net 30/45. JAV B2B kontekste tai pasitikėjimo valiuta.
- **Sprendimo priėmėjas** — vardas ir pareigos. Jei kortelėje sėdi stažuotojas, produktas miręs.
- **Fit score su paaiškinimu** — kodėl būtent šis. „Juodos dėžės" algoritmas B2B kontekste nepriimtinas.

---

## 4. Sunkiausia problema: likvidumas (chicken-and-egg)

Dvipusė rinka miršta, jei denis tuščias. Skaičiai, kuriuos reikia pasiekti:

- Vartotojui reikia **≥15 kokybiškų kortelių per savaitę**, kitaip jis negrįžta.
- **~1 iš 5 connect turi virsti match**, kitaip patiriama „šaukiu į tuštumą".
- Match → susitikimas konversija turi būti **>40%**, kitaip match'as bevertis.

Prototipe šios metrikos rodomos „Funnel" skydelyje — tai ne dekoracija, o pagrindinis produkto sveikatos rodiklis.

**Startavimo strategija (nerekomenduoju startuoti nacionaliniu mastu):**

1. **Vienas metro + viena vertikalė.** Pvz. Čikagos metro × gamyba (Tier-2 tiekėjai). ~4 tūkst. įmonių — pakankamai denio tankiui, pakankamai mažai, kad būtų galima suvesti rankomis.
2. **Vieną pusę užpildyti rankomis.** Pirkėjų poreikiai („Looking for") importuojami iš viešų RFP, prekybos asociacijų narių sąrašų, parodų dalyvių. Tiekėjai — pardavimai po vieną.
3. **Concierge etapas.** Pirmus 3–6 mėn. match'us peržiūri žmogus prieš juos rodant. Tai brangu, bet apsaugo nuo spam'o, kuris nužudė visus pirmtakus.
4. Tik po to plėtra: metro po metro, vertikalė po vertikalės.

---

## 5. Monetizacija

Nerekomenduoju consumer-dating modelio (prenumerata visiems). JAV B2B kontekste geriausiai veikia:

| Modelis | Kaina | Komentaras |
|---|---|---|
| **Freemium** | $0 | 5 kortelės/dieną, 1 connect. Būtinas denio tankiui. |
| **Pro** (pardavėjas) | $149–$299/mėn. | Neriboti connect, matomumas kas peržiūrėjo, intro šablonai |
| **Buyer** (pirkėjas) | $0 | Pirkėjai **niekada** nemoka — jie yra prekė. Tai svarbiausias vienetinės ekonomikos sprendimas. |
| **Success fee** | 1–3% nuo pirmo sandorio | Tik verifikuotiems sandoriams; sunku sekti, bet didina LTV |
| **Duomenys** | $10K+/metus | Anoniminti paklausos signalai („kas perka X Vidurio Vakaruose") |

**Vienetinė ekonomika, kurią reikia įrodyti:** CAC pardavėjui JAV B2B SaaS šiame segmente realiai $600–1 200. Prie $199/mėn. ir 18 mėn. vidutinės gyvavimo trukmės LTV ≈ $3 580 → LTV/CAC ≈ 3,0–5,9. Veikia, **jei churn < 5%/mėn.** — o tai priklauso vien nuo denio tankio.

---

## 6. Teisinė ir rizikos dalis (JAV specifika)

- **CAN-SPAM** — netaikoma vidinėms platformos žinutėms, bet taikoma el. pašto notifikacijoms. Reikia unsubscribe kiekviename laiške.
- **TCPA** — jei planuojami SMS priminimai, būtinas aiškus opt-in. Baudos $500–$1 500 už žinutę — tai realus egzistencinis pavojus.
- **State privacy laws** (CCPA/CPRA Kalifornijoje, plius ~20 kitų valstijų) — įmonių kontaktų duomenys dažnai yra ir asmens duomenys. Reikia „do not sell" mechanizmo.
- **Duomenų šaltiniai** — LinkedIn scraping'as yra teisinė minų laukas (*hiQ v. LinkedIn* nepadarė jo saugaus). Rinkti tik savanoriškai suvestus + viešus registrų duomenis (SAM.gov, valstijų Secretary of State, D&B licencija).
- **Verifikacija** — jei rodomas „D-U-N-S verified" ženklas, jis turi būti tikrai patikrintas. Klaidingas pasitikėjimo ženklas = atsakomybė.
- **Spam rizika** — didžiausia produkto rizika. Vienas agresyvus pardavėjas, siunčiantis 200 connect per dieną, sugriauna patirtį visiems. Reikia griežtų dienos limitų (prototipe — ribotas denis) ir reputacijos balo.

---

## 7. Konkurencija JAV šiandien

- **LinkedIn Sales Navigator** ($99–$179/mėn.) — didžiausias konkurentas. Privalumas: duomenys. Trūkumas: nerodo *intento* — nežinai, kas dabar perka.
- **Alignable** — smulkaus verslo tinklas, stiprus lokaliai, silpna suvedimo logika.
- **ThomasNet / Thomas** — pramoninio pirkimo katalogas, senas UX, bet reali paklausa.
- **RangeMe, Faire** — įrodė, kad intent-matching veikia mažmenoje. Geriausias precedentas.
- **Mybzz, Meetworth, B-Match** — nauji swipe tipo žaidėjai, bet visi vėl orientuoti į *networking*, ne į sandorį. Tai patvirtina rinkos susidomėjimą ir kartu palieka poziciją laisvą.

**Diferenciacija viena eilute:** LinkedIn rodo *kas yra*; Deal Deck rodo *kas perka dabar*.

---

## 8. Prototipo apimtis ir ko jame nėra

**Yra:** intent modelis, 12 realistiškų JAV įmonių profilių, skaidrus fit scoring (5 komponentai, 100 balų), swipe/klaviatūra/mygtukai, undo, mutual match logika, intro žinutės generavimas, piltuvėlio metrikos, localStorage būsena, šviesi/tamsi tema.

**Nėra (sąmoningai):** backend, autentifikacija, mokėjimai, realus žinučių siuntimas, verifikacijos integracijos (D&B API), mobilios aplikacijos apvalkalas. Tai apie 6–10 savaičių darbo su vienu full-stack inžinieriumi iki realaus MVP.

**Kitas žingsnis, jei tęsiame:** ne kodas, o 30 pokalbių su Čikagos metro gamybos įmonių pirkimų vadovais. Klausimas jiems vienas: *„Parodykite paskutinius tris tiekėjus, kurių ieškojote — kaip juos radote ir kiek tai užtruko?"* Atsakymai nulems, ar swipe apskritai reikalingas.

---

## Šaltiniai

- [Shapr alternatives — mybzz.com](https://mybzz.com/shapr-alternative)
- [Bumble Bizz uždarymas — dude-hack.com](https://dude-hack.com/how-does-bumble-bizz-work-what-it-is-how-to-use-it/)
- [Ripple, Tinder spinoff — TechCrunch](https://techcrunch.com/2018/01/08/ripple-a-tinder-spinoff-backed-by-match-launches-app-for-professional-networking/)
- [LinkedIn vs Lunchclub vs Shapr — scale.jobs](https://scale.jobs/blog/linkedin-vs-lunchclub-vs-shapr-best-professional-networking-apps)
- [Bumble Bizz paleidimas — Fortune](https://fortune.com/2017/10/02/bumble-launches-bumble-bizz)
