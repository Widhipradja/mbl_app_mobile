# Backend API changes — Zakat Fitrah year scoping

Living list of API changes the mobile app needs (or already sends) so that all
Zakat Fitrah data follows the year chosen in the app bar. Add a row whenever the
app changes what it sends to, or expects from, the API.

Base URL: `https://baraka-api.sangkarahub.app`

## 0. Status on the backend (from the BE's `API_CHANGES.md`)

Implemented by the BE and matching what the app sends: 1.1 recent transactions
`year_id`, 1.2 per-year configurations (`year_id`, global + year rows, unique
`(group, module, code, year)`), 1.4 akad correction, 1.5 amil `year_id`, 1.6 Master
Eksternal (`/externals`, `external_id` on muzakki and external souls, migration
`-migrate-externals`), and the 1.7 prerequisites (`/muzakki/bulk` accepts rows
without status and with `external_id`, `limit` up to 5000, `POST /distributions`
returns `data.id`). Verification endpoints are deprecated but still work.

Still to do before the app is tested end to end:
- Run the BE migration (`-migrate-externals -dry-run`, then for real) and check the
  Master Eksternal list for merged spellings.
- The mobile gateway `/api/m/v1/*` is **not used by the app yet** and is untested
  against the real hubs.

Behaviour the app now follows because of the BE rules:
- Internal muzakki never carry an `external_id` (create, edit, and the year sync).
  The sync sends `external_id` only for non-internal rows and no longer sends
  `afiliasi`.
- Master Eksternal: names are max 50 characters (the dialog enforces it); a
  duplicate name (409) and deleting an external still in use (409) show specific
  messages in Config.
- `GET /configurations…` without `year_id` returns only global rows; the app always
  passes the selected year where it needs a per-year value.
- `POST /muzakki/bulk` (Excel import) matches `group_name` of non-internal rows to
  Master Eksternal when no `external_id` is sent, which answers the open question
  in 1.6: the app keeps sending `group_name` for Excel rows.
- `limit` on muzakki status is now up to 5000. The Muzakki and Beranda screens still
  request 400, which is enough for the current size; raise it if a year grows past
  that.

## 1. Needs BE work

### 1.1 `GET /api/zakat-fitrah/transactions/recent` — accept `year_id`
- **App now sends:** `?limit=10&year_id=<uuid>` (previously only `limit`).
  Source: `ApiService.getZakatRecentTransactions` (`lib/services/api_service.dart`).
- **BE to do:** filter by `year_id` when present, then order by `created_at DESC`
  and apply `limit`. `year_id` stays optional.
- **Why:** the Beranda "Transaksi Terbaru" list showed the same latest 10
  transactions regardless of the selected year.
- **Interim behaviour:** until the BE filters, the app drops rows whose
  `year_id` differs from the selected year. If the BE ignores the parameter, a
  year with no recent activity can show fewer than 10 rows, or none, even when
  that year has older transactions.
- **Response:** unchanged. Each item must keep returning `year_id`, which the
  app's fallback filter relies on.

### 1.2 Configurations: `TITIP_UANG` and `IKRAR_ZAKAT` are per year — decided
Decision: these two values differ per Zakat year. Other `ZAKATFITRAH` configs
(`GROUP`, `LOCATION`, `LOCATION_ADDR`, …) stay global.

Contract (app already implements it):
- Add nullable `year_id` to the configuration record. Returned in every
  response; accepted on `POST` / `PUT` (`year_id` omitted or empty = global).
- `GET /api/zakat-fitrah/configurations/module/{module}?year_id=<uuid>` returns
  the global rows **plus** that year's rows. (If the BE returns all rows, the app
  still keeps only global rows and rows of the selected year.)
- Resolution (done in the app, and wanted on the BE for the single-value
  endpoints `…/module/{module}/code/{code}` and `…/code/{code}/value`, which
  should take optional `?year_id=`): *year-specific row → global row (year_id null)*.
- Uniqueness (confirmed by BE): `(module, code, year_id)` — one global row and at most one row per
  year for the same code. Existing rows keep `year_id = null` and act as the
  default for years without their own value.

App behaviour: Config shows the selected year's value; if only the global value
exists the row says "Belum diatur untuk tahun ini — memakai nilai umum", and
editing it creates this year's own row (the global row is not changed). Payment
form and akad dialog read `TITIP_UANG` / `IKRAR_ZAKAT` for the selected year.
"Salin dari Tahun Sebelumnya" copies a source year's own values to the target
year (skipped if the target already has one).

### 1.3 Verification removed — akad is the completion
The app no longer shows or calls verification. Saving a transaction now always
sends `serah_terima: {"mode": "akad", "amil_name": "..."}` with the bulk
payment (amil is required in the form), so paid + akad happen in one step.
`mode: "titip"` is no longer sent.

- **No longer called by the app:**
  - `PATCH /api/zakat-fitrah/muzakki/{id}/verify`
  - `GET /api/zakat-fitrah/muzakki/verification-recap`
  Both can be deprecated. `is_verified` can stay in the database; the app
  ignores it.
- **Please confirm on BE:**
  1. `POST /transactions/bulk` with `serah_terima.mode = "akad"` sets
     `is_akad_done = true` for every member in the payment, not only the
     representative.
  2. No report or snapshot computation filters on `is_verified`.
  3. Run once before release to find old rows that were verified but never
     akad'd (they will now show as "Belum Akad"):
     `SELECT COUNT(*) FROM muzakki WHERE is_verified AND NOT is_akad_done;`
- **App side:** the Laporan "Rekap Verifikasi" card became "Rekap Akad Muzakki",
  computed from the muzakki list (`is_akad_done`), so it needs no endpoint.
  Muzakki cards show "Selesai · {amil}" once akad is done.

### 1.4 Akad must stay correctable — BE in progress
The app treats akad as an editable status, not a lock. The BE needs to support:
- `POST /transactions/bulk` for a family that already has a transaction must
  **update** the amount and amil and keep `is_akad_done = true`, not reject or
  duplicate (used by **Edit Bayar**).
- `PATCH …/muzakki/{id}/akad` with `{"status": false}` must clear `is_akad_done`
  and the stored amil name (used by **Koreksi: Tandai Belum Akad**; the app sends
  it without `representative`).

App entry points: **Edit Bayar** (amil pre-selected), **Ubah Akad** on the family
card (`PATCH …/muzakki/family/{family_id}/akad`, `status: true` with a new
`amil_name`), and long-press a muzakki → **Koreksi: Tandai Belum Akad**.

Until the BE change is deployed, Edit Bayar on an akad'd family and Koreksi may
fail or leave the old status.

### 1.5 `GET /api/zakat-fitrah/amil` — filter by `year_id`
Config → Master Amil sends `?year_id=<uuid>` (create/update bodies already carry
`year_id`). Please make sure the endpoint filters by it; until then the app drops
rows whose `year_id` differs from the selected year. Each row must keep
returning `year_id`.

### 1.6 Master Eksternal (replaces `EXTERNAL_*` / `AFILIATE_*` configs)
Afiliasi (e.g. PPM) and external groups (e.g. HUM) become one **global** list,
managed in Config → Master Eksternal. It is not per year.

**New endpoints** (`ApiService.getZakatExternals` etc.):
- `GET /api/zakat-fitrah/externals` → `[{id, name, notes, is_active}]`
  (the app also accepts `{data: [...]}`)
- `POST /api/zakat-fitrah/externals` body `{name, notes, is_active}`
- `PUT /api/zakat-fitrah/externals/{id}` same body
- `DELETE /api/zakat-fitrah/externals/{id}` — suggest rejecting (or soft
  deleting) when muzakki/souls still reference it; the app recommends
  deactivating instead.

**Changed payloads the app now sends / expects:**
| Endpoint | Change |
|---|---|
| `POST /muzakki`, `PUT /muzakki/{id}` | send `external_id` — only for non-internal muzakki (empty for internal). Still sends `group_name` (the external's name when non-internal) so older BE keeps working. `afiliasi` is no longer sent. |
| `GET /years/{yearId}/muzakki/status` | each muzakki should return `external_id` and `external_name`. Until then the app falls back to `group_name` (external muzakki) / `afiliasi` (internal) as the name. |
| `POST /transactions/bulk` | `external_breakdown` may include optional `external_id` (the external the non-registered souls belong to). |
| `external_data[].external_souls[]` (muzakki status response) | each row should return `external_id`. |

**Rules:** an external muzakki (`is_internal = false`) must have exactly one
`external_id`; an internal muzakki has none (the form no longer offers it, and
saving an existing internal muzakki clears `external_id` and `afiliasi`).

**Migration (once):** for every config row with code `EXTERNAL_*` or
`AFILIATE_*` create a master row (name = the config `value`, falling back to the
code without its prefix; merge duplicates by name), then set `external_id` on
muzakki whose `group_name` (external) or `afiliasi` (internal) matches. After
that the `EXTERNAL_*` / `AFILIATE_*` configs can be removed.

**Report:** the per-external breakdown lives only on Beranda → "Rincian per
Grup" (the Laporan copy was removed as a duplicate). It is
computed in the app from the muzakki list and `external_data`, so it needs no new
endpoint. Rows: *Internal (tanpa eksternal)*, one row per active Master Eksternal
(registered muzakki + attributed souls), and *Non-terdaftar (tanpa kelompok)*.
Each row shows orang, jiwa, titip uang (Rp and jiwa) and beras (jiwa).
`internal_by_afiliasi` and `external_breakdown` in
`GET /years/report-summary/{yearId}` are no longer used (the app still parses them).

**Excel import:** `POST /muzakki/bulk` keeps taking `group_name`; the BE matches it to
Master Eksternal (see section 0).

### 1.7 Salin dari Tahun Sebelumnya (Config) — uses existing endpoints
The app copies data from a source year into the selected year **client-side**,
so no new endpoint is required. Optional: a server-side
`POST /api/zakat-fitrah/years/{targetId}/sync` `{source_year_id, items[]}` would be
faster and atomic for large muzakki lists; the app does not call it.

What the app calls (all additive; rows already in the target year are skipped,
nothing is overwritten):
| Item | Reads | Writes | Duplicate key |
|---|---|---|---|
| Konfigurasi Zakat Fitrah | years list; `GET /configurations/module/ZAKATFITRAH?year_id=` | `PUT /years/{target}` with source `rice_rate_per_so` + `group_name` (target dates/label/status kept); `POST /configurations` for `TITIP_UANG` / `IKRAR_ZAKAT` | config code, per year |
| Muzakki | `GET /years/{id}/muzakki/status?limit=5000` (source and target) | `POST /muzakki/bulk` `{year_id: target, muzakkis[]}` in chunks of ~100, families kept together with **new** `family_id`s | first+last+surname name |
| Mustahiq | `GET /mustahiq?year_id=` | `POST /mustahiq` | name + asnaf_type |
| Asnaf & Bobot | `GET /asnaf-bobot?year_id=` | `POST /asnaf-bobot` | asnaf_type |
| Amil | `GET /amil?year_id=` | `POST /amil` | name |
| Distribusi | `GET /distributions?year_id=` | `POST /distributions` parent-first (needs the created `id` in the response, top level or under `data`) | skipped entirely if target already has a tree |

Please check:
1. `POST /muzakki/bulk` must accept the muzakki rows without payment/akad status
   (new year starts unpaid) and, ideally, `afiliasi` and `external_id` (the app
   sends them when present; unknown keys should be ignored, not rejected).
2. The `limit=5000` on muzakki status is accepted (or tell me the max page size).
3. All list endpoints above honour `year_id` (the app also drops rows whose
   `year_id` differs).
4. `POST /distributions` returns the created `id`.
5. `TITIP_UANG` and `IKRAR_ZAKAT` are per year (see 1.2), so the "Konfigurasi
   Zakat Fitrah" item also copies them: it reads
   `GET /configurations/module/ZAKATFITRAH?year_id=` for both years and, for each
   of these codes that the source year owns and the target does not,
   `POST /configurations` with `year_id` = target. Needs `year_id` on the
   configuration record (1.2). Master Eksternal and the other global configs are
   not per year, so nothing is copied for them.

## 2. App-side only (no BE change)

| Change | Where |
|---|---|
| Switching years clears the muzakki, external, recent-transaction, report-summary and asnaf-summary caches before reloading, so a failed fetch can't show the previous year's data. | `ZakatProvider.selectYear` |
| Home page "Ringkasan" cards (kegiatan terdekat, jimpitan, penggalangan dana, shodaqoh; plus saldo kas for Administrator/KI/KU). Calls `GET /api/m/v1/home` once, and `GET /api/ku/transaction/summary/categories` for the saldo card. Reads `next_event` (`title|name`, `start_date`, `start_time`, `location`), `jimpitan` (`total`, `contributors`, `late_count`), `fundraising` (list or `{campaigns[]}` with `title`, `target`, `collected`, `progress_percent`), `shodaqoh` (`participation_count`, `total_members`). Each section's `{error}` shows "Belum tersedia" without hiding the others. | `HomeSummaryProvider`, `HomeSummarySection` |
| Home cards open read-only screens and follow the server flags. `GET /api/m/v1/config` is read as a flat object, a list of `{code, value}`, or `{modules: {...}}`; `MODULE_EVENTS / JIMPITAN / FUNDRAISING / SHODAQOH = false` hides that card, `ORG_NAME` is shown in the section title. Screens: Kegiatan `GET /api/m/v1/events?month=YYYY-MM` (`title`, `start_date`, `start_time`, `end_time`, `location`, `level`, `description`, `materials[].title/speaker`), Jimpitan `GET /api/m/v1/jimpitan?month=` + `/jimpitan/transactions?month=` (`amount`, `description`, `requested_date`, `is_setoran_recap`), Penggalangan Dana `GET /api/m/v1/fundraising` (`title`, `description`, `target`, `collected`, `progress_percent`). Lists may be bare arrays or under `data`. 503/504 show specific messages. | `lib/screens/info/info_screens.dart`, `HomeSummaryProvider` |
| After `GET /api/zakat-fitrah/years` reloads (e.g. after editing a year), the selected year is replaced with the fresh object so edits like `rice_rate_per_so` apply immediately. | `ZakatProvider.fetchYears` |

## 3. Already year-scoped (for reference)

Muzakki status `GET /years/{yearId}/muzakki/status` (includes `external_data`),
report summary `GET /years/report-summary/{yearId}`, mustahiq (+ summary/asnaf),
asnaf-bobot (+ lookup), distributions, adjustments, amil (+ active, kpi),
muzakki verification recap, family zakat resume, and the `year_id` sent on
transaction, muzakki, mustahiq and asnaf-bobot writes.

## 4. Open questions for BE
1. Does `GET /transactions/recent` also need a `limit` cap when `year_id` is given?
2. Per-year configurations: decided for `TITIP_UANG` / `IKRAR_ZAKAT` (see 1.2); uniqueness `(module, code, year_id)` confirmed by BE.
