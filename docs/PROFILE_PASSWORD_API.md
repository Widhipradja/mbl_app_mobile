# Ubah Profil & Ubah Password — API final (dibangun di BE barakafunds)

Base `/api/m/v1`, `Authorization: Bearer <token>`; user dari token, tanpa user id.
Error di field `error`. **Hanya 401 yang berarti sesi berakhir** (app logout); 403, 409,
422, 429, 502 tidak pernah logout.

| Aksi | Call |
|---|---|
| Baca profil | `GET /profile` → datar: `user_id, first_name, last_name, name, email, phone, sex` (+ `firstname, lastname, address, avatar` lama). Tanpa `sex` = akun belum terhubung ke satu anggota (read-only). |
| Ubah profil | `PUT /profile` — parsial: `first_name, last_name, email, phone, sex`; `current_password` **wajib bila email berubah**. |
| Ubah password | `PUT /password` — `current_password, new_password, confirm_password`. |

Respons profil tidak memuat `roles`, `tenant_id`, `group_name` (ambil dari `GET /auth/me`).

## Cara app memakai

- Layar Ubah Profil memuat `GET /profile`; User ID tampil tapi tidak bisa diubah dan tidak
  dikirim. Jika `sex` tidak ada, form read-only dengan penjelasan dan tombol Simpan mati.
- `PUT /profile` hanya mengirim field yang berubah dari profil server. Kolom "Password saat
  ini" muncul saat email diubah dan dikirim sebagai `current_password`. Tanpa perubahan,
  layar langsung menutup.
- Respons (datar) memperbarui user lokal; `roles`, `tenant_id`, `group_name`, `avatar`
  lokal dipertahankan.
- Pesan `error` ditampilkan apa adanya untuk 403, 409, 422, 429, dan 502 yang berakhir
  "Simpan ulang." Selain itu: 400 dan 502/503/504 memakai pesan tetap app. Untuk 502
  "Simpan ulang", user menekan Simpan lagi (request sama, password disertakan lagi).
- Password baru dicek di app: min 8 karakter, maks 72 byte UTF-8, huruf dan angka, beda
  dari yang lama, konfirmasi sama; server yang menentukan.
- Interceptor Dio tidak lagi mencetak payload error untuk path `profile`, `password`,
  dan `login`.

Code: `ApiService.getProfile / updateProfile / changePassword`,
`AuthProvider.updateProfile`, `lib/screens/profile/`.
