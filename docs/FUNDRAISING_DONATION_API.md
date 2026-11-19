# Donating to a fundraising campaign — how the app uses the endpoint

Backend contract (confirmed). Code: `ApiService.donationRequest` /
`submitFundraisingDonation` (`lib/services/api_service.dart`) and the form in
`lib/screens/info/donation_form_screen.dart`.

`POST /api/m/v1/fundraising/{campaign_id}/donations`, `multipart/form-data`, with the
login token and an `Idempotency-Key` header. `campaign_id` is `campaigns[].id` of
`GET /api/m/v1/fundraising`.

| Field | What the app sends |
|---|---|
| `amount` | Digits only, whole rupiah (`50000`), more than 0, at most 12 digits. |
| `paid_date` | `YYYY-MM-DD`, the transfer date the donor picks (today by default, no later than today, up to a year back). |
| `notes` | Optional, at most 500 characters; left out when empty. |
| `proof` | JPEG, PNG or PDF, at most 5 MB. |

Nothing else is sent: no `member_id` or `donor_name`; the donor comes from the token.
No Content-Type is forced, so Dio builds the multipart one with its boundary. The
request waits up to 90 seconds (the other calls use 10).

## Proof

Chosen from the gallery or as a file (JPG, PNG, PDF). The app reads the first bytes of
the file, as the server does, and refuses anything that is not JPEG, PNG or PDF
(WebP included, whatever its name) and anything over 5 MB, before sending.

## Idempotency-Key

A random UUID v4 for each donation attempt. The same key is reused when the donor sends
the same donation again after a failure (a timeout, no connection); it is replaced as
soon as the amount, date, note or proof changes, and every new form starts with a new
one. A new donation to the same campaign therefore never reuses an old key.

## Answers

| Status | What the app does |
|---|---|
| 202 `{donation_id, status: "pending"}` | Closes the form and says "Donasi terkirim. Menunggu verifikasi bendahara." The campaign shows "Menunggu verifikasi" for that visit. The contribution list changes only after KU approves. |
| 400 | "Donasi ditolak server: " plus the server's `error` text (it names the field). |
| 401 | The app's global handler signs the user out. |
| 404 | "Akun Anda belum terhubung ke data anggota, atau penggalangan dana ini sudah tidak menerima donasi." |
| 409 | The key was already approved: treated as done ("Donasi ini sudah disetujui."). |
| 502 / 503 / 504 | "Layanan sedang tidak tersedia. Coba lagi nanti." |
| no answer (timeout, no connection) | "Tidak ada jawaban dari server…"; the form stays and sending again reuses the key. |

## Not done

- Pending donations are not listed anywhere: the server does not return them, so
  "Menunggu verifikasi" is only remembered while the screen is open.
- Decimals in `amount` (the server accepts up to two) are not offered; the form takes
  whole rupiah.
