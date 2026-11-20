# Setor Amal Jariyah (self service) — how the app uses the API

Gateway `/api/m/v1`, login token, no member id (taken from the token).

| Step | Call |
|---|---|
| Report | `GET shodaqoh/me/family-report?period=YYYY-MM` / `family-report-yearly?year=` |
| Months not yet deposited | `GET shodaqoh/me/pending-periods` → `[{period_month, ...}]` |
| Required items of a month | `GET shodaqoh/me/collection?month=YYYY-MM` → `allocations[]` |
| Additional item catalog | `GET shodaqoh/me/items?is_additional_item=true&is_active=true` → array |
| Send | `POST shodaqoh/me/collection?month=YYYY-MM` (`month` = the current month) |

`POST` is `multipart/form-data`: `payload` (JSON string) and `proof` (required; JPEG, PNG
or PDF, max 5 MB, checked by its first bytes before sending). The gateway uploads the
proof, then submits to shodaqoh; if shodaqoh refuses (4xx) the proof is deleted.

`payload`: `{"entries": [{collected_for_period, items?, additional_items?, notes?,
collected_at?}]}`. `collected_for_period` is unique and not later than `month`.

- Required item: `{item_snapshot_id, actual_amount}` (from `allocations[]`).
- Additional item: `{catalog_item_id?, item_name, group?, actual_amount}`; the catalog
  `id` is `catalog_item_id`; a free-typed item has only `item_name`.
- `actual_amount` is a decimal string (the app sends whole rupiah, e.g. `"50000"`).
  Items left at 0 are not sent. Each entry needs a non-empty `items` or `additional_items`.
- Never sent: `status`, `tenant_id`, `created_by`, `collection_method`, `collected_by`,
  `proof_file_id`. The server stores every entry as `pending` until verified.

Errors: 400/404/409 `error` text from shodaqoh is passed through (409 = month already
entered); 401 sign in again; 403 tenant required or no access; 502/503/504 static message.

## Form

- Required items are grouped by `group` in the order Pusat, Daerah, Desa, Kelompok
  (ignoring case and surrounding spaces), other groups last, then by `sort_order`, then as
  the server sent them. A heading shows the group.
- "Shodaqoh tambahan": the active catalog, same ordering, then "Tambah shodaqoh lain" for a
  free-typed item (name and amount). If the catalog call fails the form still works.
- A month in `pending-periods` shows the "Setor" button (never decided by the amounts).
  The report opens on the latest month that has data.

Not done: several months in one request (each `period_month` of `pending-periods` could be
an entry); showing `me/history` / `me/collection-history`.
