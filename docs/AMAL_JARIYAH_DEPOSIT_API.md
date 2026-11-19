# Setor Amal Jariyah (self service) — how the app uses the API

Gateway `/api/m/v1`, login token, no member id (taken from the token).

| Step | Call |
|---|---|
| Report | `GET shodaqoh/me/family-report?period=YYYY-MM` / `family-report-yearly?year=` |
| Months not yet deposited | `GET shodaqoh/me/pending-periods` |
| Items of a month | `GET shodaqoh/me/collection?month=YYYY-MM` |
| Send | `POST shodaqoh/me/collection?month=YYYY-MM` |

POST is `multipart/form-data`: field `payload` = the JSON below as a string, field `proof` =
required file (JPEG, PNG or PDF, at most 5 MB, checked by its first bytes before sending).
The gateway uploads the proof to finance-hub and passes `proof_file_id` to shodaqoh; if
shodaqoh refuses, the proof is deleted again. KU views it via `files/view/:id`.

`payload`: `{"entries": [{collected_for_period, items?, additional_items?, notes?,
collected_at?}]}`; each item `{item_snapshot_id, amount}` (`item_snapshot_id` from GET
collection). Rules: `collected_for_period` <= `month`, no duplicate period, each entry
has a non-empty `items` or `additional_items`. The app sends one entry (the month on
screen) with `collected_at` = now (UTC ISO) and leaves out empty arrays and notes.
Never sent: `status`, `tenant_id`, `created_by`, `collection_method`, `collected_by`.
The server makes it `pending` until the treasurer (KU) verifies.

Errors: 400 and 409 show the server's Indonesian `error` text as is (409 = month already
input, or more than one member); 401 sign-in again; 403; 404 not linked to a member;
502/503/504 "Layanan sedang tidak tersedia".

UI: Buku Amal Jariyah, "Bulanan". The "Setor" button follows the backend, never the
amounts: it shows only for a month listed in `pending-periods` (not while that is
loading or if it failed). A month with total 0 that is not pending has no button.
Code: `AmalDepositFormScreen`, `ApiService.getPendingPeriods / getCollection /
submitCollection`.

## Response shapes (confirmed from real examples)

- `GET collection`: `allocations[]` with `item_snapshot_id`, `item_code`, `item_name`,
  `group`, `final_amount` (decimal string). The form lists each allocation with
  `final_amount` as the suggested amount; the member can change it. Everything is sent
  under `items`.
- `GET pending-periods`: a bare array of `{period_month: "YYYY-MM", ...}`; `[]` when
  all are deposited.

Not done: several months in one request (`period_month` values could each be an entry);
showing status from `me/history` / `me/collection-history`; `additional_items` (no
source for them in `GET collection`).
