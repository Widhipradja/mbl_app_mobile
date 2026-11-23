# Budget Pribadi — kebutuhan API untuk laporan

Untuk: pengembang backend baraka-api (modul `budget`).
Dari: mobile app Baraka. Acuan: `baraka-api:0.44` (spek `baraka-mobile-budget-api.md`).

Aturan yang sama dengan endpoint budget yang sudah ada:

- Bearer token; `tenant_id` dan `user_id` diambil dari token, tidak pernah dari klien.
- Modul `budget` mati untuk role ini → `403 {"error":"module budget is not enabled for your role"}`.
- Semua angka uang dikirim sebagai **string desimal** (`"25000"`), bukan number.
- Bulan ditulis `YYYY-MM`. Satu transaksi masuk ke bulan menurut `trx_date`.
- Data privat per user; tidak ada endpoint admin.

---

## 1. Kenapa perlu endpoint baru

Layar **Laporan** di app (per kategori, perbandingan bulan lalu, tren, transaksi terbesar)
sekarang dibangun dari endpoint yang ada, dan itu boros:

| Yang dibutuhkan layar | Cara sekarang | Masalah |
|---|---|---|
| Tren 6 bulan | `summary` dipanggil **6 kali** | 6 request per buka layar; lambat di jaringan seluler |
| Perbandingan dengan bulan lalu | ikut dari panggilan di atas | dihitung di klien |
| Pengeluaran terbesar | `transactions?limit=200`, urut di klien | transaksi lebih dari 200 tidak terbaca |
| Jenis transaksi (masuk/keluar) | tidak ada di respons transaksi; klien mencocokkan `category_id` ke `/categories` | transaksi tanpa kategori atau kategori terhapus tidak diketahui jenisnya |
| Daftar transaksi bulan ramai | `limit` maksimum 200, tanpa halaman berikutnya | data terpotong |

Prioritas: **P1** dikerjakan dulu (menghapus 6 panggilan dan celah data), **P2** menambah laporan,
**P3** nanti.

---

## 2. P1 — perbaikan pada endpoint yang ada

### 2.1 Respons transaksi membawa jenisnya

`GET /api/m/v1/budget/transactions` dan respons POST/PUT/voice: tambahkan dua field.

```json
{
  "id": "c9581a9d-…",
  "category_id": "78fb99a3-…",
  "category_name": "Gaji",
  "category_type": "income",
  "amount": "500000",
  "…": "field lain tidak berubah"
}
```

- `category_type`: `income` atau `expense`. Nilainya **disimpan di transaksi saat dibuat**
  (seperti `category_name`), supaya tetap benar setelah kategori dihapus atau diubah jenisnya.
- Transaksi tanpa kategori: `category_type` diisi `null`, bukan string kosong.

### 2.2 Filter jenis dan halaman berikutnya

```
GET /api/m/v1/budget/transactions?from=2026-11-01&to=2026-11-30&type=expense&limit=50&offset=0
```

- `type` (opsional): `income` atau `expense`. Selain itu `400`.
- `offset` (opsional, default 0).
- Total tersedia di header respons, supaya bentuk respons (array) tidak berubah:

```
X-Total-Count: 137
```

---

## 3. P1 — tren bulanan dalam satu panggilan

```
GET /api/m/v1/budget/reports/monthly?from=2026-06&to=2026-11
```

`from` dan `to` termasuk. Maksimum 24 bulan, selebihnya `400 {"error":"range is too long"}`.

```json
{
  "from": "2026-06",
  "to": "2026-11",
  "months": [
    {"month":"2026-06","income":"1200000","expense":"800000","net":"400000","transaction_count":31},
    {"month":"2026-07","income":"0","expense":"0","net":"0","transaction_count":0}
  ],
  "average_expense": "650000",
  "average_income": "900000"
}
```

- **Semua bulan dalam rentang selalu ada**, juga yang kosong (nol), urut dari yang lama.
- `average_*` = rata-rata dari bulan **yang ada transaksinya**, bukan dibagi jumlah bulan rentang.
  Kalau tidak ada satu pun, `"0"`.

---

## 4. P1 — laporan per kategori

```
GET /api/m/v1/budget/reports/categories?month=2026-11&type=expense
```

`type` wajib (`income` atau `expense`). `month` kosong = bulan berjalan.

```json
{
  "month": "2026-11",
  "type": "expense",
  "total": "850000",
  "previous_month": "2026-10",
  "previous_total": "700000",
  "change_percent": 21.43,
  "daily_average": "38636",
  "days_counted": 22,
  "items": [
    {
      "category_id": "2add142b-…",
      "category_name": "Makan",
      "amount": "400000",
      "share_percent": 47.06,
      "previous_amount": "300000",
      "change_percent": 33.33,
      "transaction_count": 14
    },
    {
      "category_id": null,
      "category_name": "Tanpa kategori",
      "amount": "50000",
      "share_percent": 5.88,
      "previous_amount": "0",
      "change_percent": null,
      "transaction_count": 2
    }
  ]
}
```

Aturan:

- `items` urut `amount` turun. Kategori **tanpa transaksi di bulan itu tidak dimasukkan**.
- Transaksi tanpa kategori atau dengan kategori yang sudah dihapus dikelompokkan per
  `category_name` yang tersimpan; yang benar-benar kosong menjadi satu baris
  `category_id: null`, `category_name: "Tanpa kategori"`.
- `share_percent` = `amount / total × 100`; jumlah seluruh item = 100 (selisih pembulatan boleh).
- `change_percent` = `(amount − previous_amount) / previous_amount × 100`;
  **`null` bila `previous_amount` = 0** (app menampilkan "baru"). Boleh negatif.
- `change_percent` tingkat atas memakai aturan yang sama terhadap `previous_total`.
- `daily_average` = `total / days_counted`, dibulatkan ke rupiah. `days_counted` = jumlah hari
  di bulan itu; untuk **bulan berjalan** = tanggal hari ini (jangan membagi dengan 30 pada
  tanggal 5). Hanya berarti untuk `type=expense`, tetap dikirim untuk `income`.

---

## 5. P2 — pengeluaran harian dan transaksi terbesar

### 5.1 Per hari

```
GET /api/m/v1/budget/reports/daily?month=2026-11
```

```json
{
  "month": "2026-11",
  "days": [
    {"date":"2026-11-01","income":"0","expense":"25000"},
    {"date":"2026-11-02","income":"0","expense":"0"}
  ],
  "busiest_expense_day": {"date":"2026-11-14","expense":"260000"}
}
```

Semua tanggal bulan itu selalu ada. `busiest_expense_day` = `null` bila tidak ada pengeluaran.

### 5.2 Transaksi terbesar

```
GET /api/m/v1/budget/reports/top-transactions?month=2026-11&type=expense&limit=5
```

Respons: array transaksi (bentuk sama dengan §2.1) urut `amount` turun. `limit` default 5,
maksimum 20. Menggantikan pengambilan 200 transaksi lalu mengurutkan di klien.

### 5.3 Laporan tahunan

```
GET /api/m/v1/budget/reports/yearly?year=2026&type=expense
```

```json
{
  "year": 2026,
  "type": "expense",
  "total": "9600000",
  "months": ["2026-01","2026-02","…","2026-12"],
  "items": [
    {
      "category_id": "2add142b-…",
      "category_name": "Makan",
      "total": "4800000",
      "monthly_average": "400000",
      "by_month": ["400000","350000","0","…"]
    }
  ],
  "month_totals": ["800000","700000","…"]
}
```

`by_month` dan `month_totals` selalu 12 elemen, urut Januari–Desember, sejajar dengan `months`.
Aturan kategori kosong/terhapus sama seperti §4. `monthly_average` dibagi bulan yang sudah
berjalan (bulan depan belum dihitung untuk tahun berjalan).

---

## 6. P3 — nanti

### 6.1 Riwayat anggaran vs realisasi

```
GET /api/m/v1/budget/reports/budget-history?from=2026-06&to=2026-11
```

```json
{
  "months": [
    {
      "month": "2026-11",
      "limit_total": "300000",
      "spent_in_budget": "275000",
      "over_count": 1,
      "items": [
        {"category_id":"…","category_name":"Makan","limit":"300000","spent":"325000",
         "remaining":"-25000","percent":108.33}
      ]
    }
  ]
}
```

Hanya kategori pengeluaran yang punya `limit` > 0 di bulan itu. Aturan `remaining` dan
`percent` sama dengan `/budget/summary` (boleh negatif / lebih dari 100).

### 6.2 Proyeksi akhir bulan

```
GET /api/m/v1/budget/reports/forecast?month=2026-11
```

```json
{
  "month": "2026-11",
  "spent_so_far": "850000",
  "days_elapsed": 22,
  "days_in_month": 30,
  "projected_expense": "1159091",
  "limit_total": "1000000",
  "projected_over": "159091"
}
```

Proyeksi linier: `spent_so_far / days_elapsed × days_in_month`. `projected_over` = `null`
bila `limit_total` = 0 atau proyeksi di bawah batas. Hanya untuk bulan berjalan; bulan lain
`400 {"error":"forecast is only available for the current month"}`.

### 6.3 Ekspor

```
GET /api/m/v1/budget/reports/export?month=2026-11&format=csv
```

`format`: `csv` atau `pdf`. Respons berkas biner dengan `Content-Disposition: attachment;
filename="budget-2026-11.csv"`. Isi minimal: transaksi bulan itu (tanggal, kategori, jenis,
nominal, keterangan) dan ringkasan per kategori. Batas ukuran sama dengan tarik data biasa;
CSV memakai pemisah koma dan UTF-8 dengan BOM agar terbuka benar di Excel.

---

## 7. Error

Sama dengan endpoint budget lain:

| Status | Body | Arti |
|---|---|---|
| 400 | `{"error":"month must be YYYY-MM"}` | format bulan salah |
| 400 | `{"error":"type must be income or expense"}` | `type` salah atau kosong di endpoint yang mewajibkannya |
| 400 | `{"error":"range is too long"}` | `monthly` lebih dari 24 bulan |
| 401 | kosong | token kedaluwarsa |
| 403 | `{"error":"module budget is not enabled for your role"}` | modul ditutup |

---

## 8. Catatan implementasi

- **Zona waktu:** `trx_date` hanya tanggal. Kelompokkan per bulan/hari menurut tanggal itu apa
  adanya, tanpa konversi zona waktu.
- **Indeks:** laporan membaca per `(tenant_id, user_id, trx_date)`; pastikan indeks gabungan itu
  ada. `reports/monthly` dan `reports/yearly` cukup satu query `GROUP BY` per panggilan.
- **Konsistensi:** `reports/categories` bulan berjalan harus sama dengan `/budget/summary` untuk
  bulan yang sama (jumlah `spent` per kategori). Itu uji terpenting.
- **Pembulatan:** hitung di sisi server dengan desimal; kirim persen dengan 2 angka di belakang
  koma, uang tanpa pecahan kecuali memang ada.
- **Bentuk respons:** array tetap array (`transactions`, `top-transactions`); objek tetap objek.
  App tidak menebak bentuknya.

## 9. Uji penerimaan

1. Buat 3 transaksi pengeluaran di 2 kategori + 1 tanpa kategori pada bulan ini, 2 transaksi di
   bulan lalu. `reports/categories?type=expense` → jumlah `items[].amount` = `total`; baris
   "Tanpa kategori" ada; `change_percent` kategori yang baru bulan ini = `null`.
2. `reports/monthly` dengan rentang 6 bulan → selalu 6 elemen, bulan kosong bernilai `"0"`.
3. Hapus sebuah kategori → transaksinya tetap muncul di laporan dengan nama dan jenis lama.
4. Bulan berjalan tanggal 5: `daily_average` = `total / 5`, bukan `/ 30`.
5. `transactions?type=expense&limit=2&offset=2` + header `X-Total-Count` konsisten dengan data.
6. User tanpa modul budget → semua endpoint di atas `403`.

## 10. Yang tetap di luar cakupan

Saldo bawaan antar bulan (carry-over), multi-dompet, target tabungan, dan berbagi anggaran —
sama seperti di spek budget: belum ada, dan laporan di atas tidak mengandalkannya.

## 11. Sisi app setelah ini tersedia

Begitu P1 live, layar Laporan beralih dari 6 panggilan `summary` ke `reports/monthly` dan
`reports/categories` (satu panggilan masing-masing), dan jenis transaksi dibaca dari
`category_type`. Beri tahu saya bentuk respons final bila ada yang berubah dari dokumen ini.
