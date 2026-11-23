# Tabungan Kurban and Buku Amal Jariyah — how the app reads the API

Gateway base path `/api/m/v1`, all `GET` with `Authorization: Bearer <login token>`.
No member id anywhere: the member comes from the token. Bodies are passed through
from shodaqoh-api unchanged.

| Endpoint | Query | Used by |
|---|---|---|
| `shodaqoh/me/qurban-savings` | – | Tabungan Kurban |
| `shodaqoh/me/family-report` | `period=YYYY-MM` | Buku Amal Jariyah, "Bulanan" |
| `shodaqoh/me/family-report-yearly` | `year=YYYY` | Buku Amal Jariyah, "Tahunan" |
| `shodaqoh/me/family-collection-summary` | `item_code=K-07` | "Target kurban" card |

Code: `ApiService` (`lib/services/api_service.dart`), parsers in
`lib/models/savings_ledgers.dart`, screens in `lib/screens/savings/`.

## What the app does with the answers

- **KK vs not.** The view follows `scope` / `is_head_of_family`, never the number of
  `members`. `scope: "family"` (or head) lists the whole family in the order given, the
  head tagged "Kepala keluarga", plus a "Total per bulan" row. `scope: "self"` shows
  one person ("Tabungan Anda" / "Catatan Anda").
- **Amounts.** Strings in `qurban-savings` and `family-collection-summary`, numbers in
  the family reports; every amount is read through one tolerant parser.
- **qurban-savings.** `cycle: null` is a normal answer: the screen says no savings
  cycle is running. Month columns come from top-level `months`. A member's `by_month`
  omits unpaid months, so each is read as 0; the top-level `by_month` has every month.
- **family-report-yearly.** `months[]` is one report per month; months with nothing are
  left out, newest first, and tapping one opens it in the monthly view.
  `earliest_year` is the limit for paging back; paging forward stops at this year.
- **Target kurban.** Shown only if the summary has a target or collected amount. If
  that call fails the savings are still shown.
- **Access.** The two tiles show for every signed-in user, since the data is scoped by
  the token.

## Errors

The server's `{"error": "..."}` text is English and fixed, so it is never shown; the
status code picks the Indonesian message:

| Status | Shown |
|---|---|
| 401 | The app's global handler signs the user out and goes to login |
| 403 | "Anda tidak punya akses ke data ini." |
| 404 | "Akun Anda belum terhubung ke data jamaah." |
| 409 | "Akun Anda terhubung ke lebih dari satu data jamaah. Hubungi admin." |
| 502 / 503 / 504 | "Layanan sedang tidak tersedia. Coba lagi sebentar lagi." |
| network / timeout | "Tidak bisa terhubung ke server. Periksa koneksi Anda." |
| 400 and others | "Data gagal dimuat." (a 400 means a bug in the app) |

## Field names the parsers assume

The shapes below were written from the endpoint description, not from a captured
response. Please compare them with a real answer.

- `qurban-savings`: `scope`, `is_head_of_family`, `cycle` (object with `name`, or
  null), `months` (list of `"YYYY-MM"`), `by_month` (`{"YYYY-MM": "amount"}`),
  `members[]` with `name`, `total`, `by_month`, and `is_head`, `total`.
- `family-report`: `scope`, `is_head_of_family`, `period`, `members[]` with `name`,
  `fr`, `shodaqoh`, `infaq`, `total`, and optional `totals`.
- `family-report-yearly`: `year`, `earliest_year`, `months[]` each shaped like one
  `family-report` (with its own `period`).
- `family-collection-summary`: `target`, `collected`.

Also accepted: `{data: ...}` wrapping, `sodaqoh`/`infak`/`fitrah` spellings, `nama` for
`name`, and a missing total (summed from its parts).
