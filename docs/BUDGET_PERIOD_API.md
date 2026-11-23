# Budget Pribadi — periode mengikuti tanggal gajian

Untuk: pengembang backend baraka-api (modul `budget`).
Dari: mobile app Baraka. Melengkapi `BUDGET_REPORTS_API.md` dan spek `baraka-mobile-budget-api.md`.

Aturan yang sama dengan endpoint budget yang sudah ada:

- Bearer token; `tenant_id` dan `user_id` diambil dari token, tidak pernah dari klien.
- Modul `budget` mati untuk role ini → `403 {"error":"module budget is not enabled for your role"}`.
- Semua angka uang dikirim sebagai **string desimal** (`"25000"`), bukan number.
- Data privat per user; tidak ada endpoint admin.

---

## 1. Latar belakang

Sekarang semua data budget dikelompokkan per **bulan kalender** (`YYYY-MM`, tanggal 1 sampai
akhir bulan). Banyak user gajian bukan tanggal 1: yang gajian tanggal 25 ingin melihat
pemasukan, pengeluaran, dan sisa anggaran untuk **25 Oktober – 24 November**, bukan 1–30 November.

Yang diminta: setiap user bisa mengatur **tanggal mulai periode** (1–28). Semua angka di
Dompet Saya (ringkasan, anggaran per kategori, laporan) lalu dihitung per periode itu.
User yang tidak mengubah apa pun tetap tanggal 1, jadi bagi mereka tidak ada yang berubah.

Kenapa di server, bukan dihitung di app:

- App tidak bisa menghitung ringkasan dan laporan sendiri tanpa menarik semua transaksi
  (batas 200, jenis masuk/keluar harus ditebak; lihat `BUDGET_REPORTS_API.md` §1).
- Anggaran (`limits`) dan laporan harus memakai batas periode yang **sama persis**. Kalau
  dihitung di dua tempat, angkanya bisa berbeda.
- Pengaturannya harus sama di semua perangkat user.

---

## 2. Pengaturan periode

### 2.1 Baca

```
GET /api/m/v1/budget/settings
```

```json
{
  "period_start_day": 25,
  "current_period": {
    "month": "2026-12",
    "start": "2026-11-25",
    "end": "2026-12-24"
  }
}
```

- `period_start_day`: bilangan bulat 1–28. **Default 1** untuk user yang belum pernah mengatur
  (tidak perlu baris di database sampai user mengubahnya).
- `current_period`: periode yang memuat **hari ini**, dengan aturan di §3. App memakainya
  sebagai periode awal saat layar dibuka.

### 2.2 Ubah

```
PUT /api/m/v1/budget/settings
{"period_start_day": 25}
```

- Respons `200`: bentuk sama dengan §2.1, sudah dengan nilai baru.
- Bukan bilangan bulat 1–28 → `400 {"error":"period_start_day must be between 1 and 28"}`.
- Kenapa maksimal 28: supaya setiap periode selalu punya tanggal mulai, juga di Februari.
  User yang gajian tanggal 29–31 memilih 28 atau 1.
- Berlaku **surut** untuk semua periode (lihat §6). Tidak perlu menyimpan riwayat pengaturan.

---

## 3. Arti `month` = periode

Parameter `month=YYYY-MM` **tetap dipakai** di semua endpoint. Bentuk API tidak berubah, yang
berubah artinya: `month` adalah **periode yang berakhir di bulan itu**, menurut
`period_start_day` milik user.

Untuk `month = Y-M` dan `d = period_start_day`:

| `d` | `start` | `end` |
|---|---|---|
| 1 | `Y-M-01` | hari terakhir bulan `Y-M` |
| 2–28 | `(Y-M dikurangi 1 bulan)-d` | `Y-M-(d−1)` |

Contoh dengan `d = 25`:

| `month` | `start` | `end` | Jumlah hari |
|---|---|---|---|
| `2026-11` | 2026-10-25 | 2026-11-24 | 31 |
| `2026-03` | 2026-02-25 | 2026-03-24 | 28 |
| `2027-01` | 2026-12-25 | 2027-01-24 | 31 |

Kenapa diberi nama menurut bulan **akhir**: gaji tanggal 25 Oktober dipakai untuk kebutuhan
November, jadi user menyebut periode itu "November". Dengan `d = 1` aturannya persis sama
dengan perilaku sekarang.

- Satu transaksi masuk ke periode yang memuat `trx_date`-nya (`start ≤ trx_date ≤ end`).
- **Periode berjalan** = periode yang memuat hari ini. "Hari ini" dihitung menurut zona waktu
  tenant (Asia/Jakarta), bukan UTC: pada pukul 00.30 WIB tanggal 25, periode baru sudah mulai.
- `month` kosong = periode berjalan (menggantikan "bulan berjalan").

---

## 4. Setiap respons menyebut batas periodenya

Semua respons yang menerima `month` menambahkan dua field di tingkat atas:

```json
{
  "month": "2026-11",
  "period_start": "2026-10-25",
  "period_end": "2026-11-24",
  "…": "field lain tidak berubah"
}
```

App **menampilkan tanggal dari server** ("November 2026 · 25 Okt – 24 Nov") dan memakai
keduanya sebagai `from`/`to` saat menarik daftar transaksi. App tidak menghitung batas
periode sendiri, jadi aturan di §3 hanya ada di satu tempat.

Endpoint yang berisi banyak periode (`reports/monthly`, `reports/yearly`,
`reports/budget-history`) menaruh `period_start`/`period_end` di **setiap elemen**.

---

## 5. Endpoint yang terdampak

### 5.1 Sudah ada

| Endpoint | Perubahan |
|---|---|
| `GET /budget/summary?month=` | `income`, `expense`, `net`, `categories[].spent` dihitung per periode. Tambah `period_start`, `period_end`. |
| `GET /budget/limits?month=` | Anggaran disimpan per **kunci periode** `YYYY-MM` (kolom yang sama seperti sekarang). Tambah `period_start`, `period_end`. |
| `PUT /budget/limits` | `month` di body = kunci periode. Tidak ada perubahan bentuk. |
| `GET /budget/transactions?from=&to=` | **Tidak berubah**: tetap rentang tanggal eksplisit. App mengisi `from`/`to` dari §4. |
| `POST`/`PUT` transaksi, voice | Tidak berubah. |

`limits` tidak perlu migrasi data: anggaran "2026-11" tetap anggaran "2026-11", hanya
rentang tanggal yang diukur dengannya yang mengikuti `period_start_day`.

### 5.2 Endpoint laporan (dari `BUDGET_REPORTS_API.md`)

Kalau laporan belum dibangun, bangun langsung dengan aturan periode ini.

| Endpoint | Perubahan |
|---|---|
| `reports/monthly?from=&to=` | `from`/`to` = kunci periode. Setiap elemen `months[]` membawa `period_start`, `period_end`. |
| `reports/categories?month=` | Per periode. `previous_month` = periode sebelumnya. Tambah `previous_period_start`, `previous_period_end`. |
| `reports/categories` → `days_counted` | Jumlah hari **periode** (28–31). Untuk periode berjalan = hari dari `period_start` sampai hari ini, inklusif. |
| `reports/daily?month=` | `days[]` berisi semua tanggal dari `period_start` sampai `period_end`, jadi bisa melewati pergantian bulan kalender. |
| `reports/top-transactions?month=` | Per periode. |
| `reports/yearly?year=` | Tahun `Y` = 12 periode yang **berakhir** di Januari–Desember `Y`. `months` tetap `["Y-01", …, "Y-12"]`; tambah array sejajar `periods: [{"start":…,"end":…}, …]`. |
| `reports/budget-history` | Per periode; setiap elemen membawa `period_start`, `period_end`. |
| `reports/forecast?month=` | `days_elapsed` / `days_in_month` dihitung dalam periode; ganti nama atau tambah `days_in_period` (app membaca `days_in_period` bila ada). Hanya untuk periode berjalan. |
| `reports/export?month=` | Isi per periode; nama berkas `budget-2026-11.csv` tetap, baris pertama menyebut rentang tanggal. |

---

## 6. Mengubah `period_start_day`

- Berlaku **surut**: semua periode, termasuk yang lalu, langsung dihitung ulang dengan tanggal
  baru. Transaksi tidak berubah, hanya pengelompokannya.
- Anggaran per kunci periode ikut, tanpa dipindah (§5.1).
- Tidak perlu menyimpan riwayat pengaturan. Konsekuensinya, laporan bulan lalu bisa berubah
  angkanya setelah user mengganti tanggal. App menampilkan peringatan sebelum menyimpan.
- Tidak ada cache laporan per user yang boleh tertinggal. Kalau ada cache, kunci cache harus
  memuat `period_start_day`, atau cache dibuang saat pengaturan diubah.

---

## 7. Error

| Status | Body | Arti |
|---|---|---|
| 400 | `{"error":"period_start_day must be between 1 and 28"}` | nilai pengaturan salah |
| 400 | `{"error":"month must be YYYY-MM"}` | format `month` salah (tidak berubah) |
| 401 | kosong | token kedaluwarsa |
| 403 | `{"error":"module budget is not enabled for your role"}` | modul ditutup |

---

## 8. Catatan implementasi

- **Satu fungsi** `periodRange(month, startDay) → (start, end)` dipakai oleh semua endpoint di §5.
  Jangan menulis ulang aturan §3 di setiap query.
- Query tetap `trx_date BETWEEN :start AND :end`. Indeks `(tenant_id, user_id, trx_date)` dari
  `BUDGET_REPORTS_API.md` §8 sudah cukup.
- `reports/monthly`/`yearly` dengan `d ≠ 1` tidak bisa lagi `GROUP BY` bulan kalender.
  Kelompokkan dengan ekspresi periode, misalnya
  `to_char(trx_date + interval '1 month' - (d - 1) * interval '1 day', 'YYYY-MM')` untuk `d > 1`
  (setara dengan aturan §3), atau `JOIN` ke deret periode yang dibangkitkan.
- **Konsistensi:** untuk periode yang sama, `summary.expense` = jumlah `reports/categories`
  (expense) = jumlah `transactions?from=period_start&to=period_end` (expense). Itu uji terpenting.

---

## 9. Uji penerimaan

1. User baru: `GET /budget/settings` → `period_start_day: 1`; semua angka sama dengan sebelum
   perubahan ini.
2. `PUT period_start_day: 25` → `summary?month=2026-11` membawa `period_start: 2026-10-25`,
   `period_end: 2026-11-24`. Transaksi tanggal 24 Okt **tidak** masuk, 25 Okt masuk,
   24 Nov masuk, 25 Nov **tidak** masuk.
3. `d = 25`, `month=2026-03` → `2026-02-25` s/d `2026-03-24` (Februari 28 hari).
   Tahun kabisat `2028-03` → `2028-02-25` s/d `2028-03-24`.
4. `d = 25`, `month=2027-01` → mulai `2026-12-25` (melewati pergantian tahun).
5. Tanggal 25 pukul 00.30 WIB (24, 17.30 UTC): `current_period` sudah periode baru.
6. Anggaran Makan Rp 300.000 di `2026-11`, `d` diubah 1 → 25: anggaran tetap di `2026-11`,
   `spent` dihitung dari 25 Okt – 24 Nov.
7. `PUT period_start_day: 29`, `0`, `"25"` (string), dan `null` → masing-masing `400`.
8. `reports/daily?month=2026-11` dengan `d = 25` → 31 elemen, dari 2026-10-25 sampai 2026-11-24.
9. User lain di tenant yang sama tidak terpengaruh pengaturan user ini.

---

## 10. Di luar cakupan

- Rentang tanggal bebas (misalnya 3–17 November) untuk laporan sekali lihat. Bisa ditambah
  nanti sebagai `from`/`to` tanggal di `reports/*`; tidak dibutuhkan untuk kasus gajian.
- Periode mingguan atau dua mingguan.
- Gajian yang bergeser karena hari libur (misalnya maju ke Jumat). User mencatat transaksi
  apa adanya; batas periode tetap tanggal yang diatur.

---

## 11. Sisi app setelah ini tersedia

- Layar baru **Pengaturan → Tanggal mulai periode** (pilihan 1–28, dengan peringatan bahwa
  laporan lama ikut dihitung ulang).
- Semua layar Dompet Saya (beranda, anggaran, transaksi, laporan) memakai `current_period`
  sebagai periode awal dan menampilkan "November 2026 · 25 Okt – 24 Nov" dari
  `period_start`/`period_end`.
- Daftar transaksi per periode memakai `from=period_start&to=period_end`.
- Selama server belum mengirim `period_start`/`period_end`, app memperlakukan semua user
  sebagai tanggal 1, jadi app baru tetap jalan dengan server lama.

Beri tahu saya bentuk respons final bila ada yang berbeda dari dokumen ini.
