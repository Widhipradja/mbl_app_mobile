# Ubah Profil & Ubah Password — API final (dibangun di BE barakafunds)

Base `/api/m/v1`, `Authorization: Bearer <token>`; user dari token, tanpa user id.
Error di field `error`. **Hanya 401 yang berarti sesi berakhir** (app logout); 403, 409,
422, 429, 502 tidak pernah logout.

| Aksi | Call |
|---|---|
| Baca profil | `GET /profile` → datar: `user_id, first_name, last_name, name, email, phone, sex` (+ `firstname, lastname, address, avatar` lama). Tanpa `sex` = akun belum terhubung ke satu anggota (read-only). |
| Ubah profil | `PUT /profile` — parsial: `first_name, last_name, email, phone, sex`; `current_password` **wajib bila email berubah**. |
| Ganti foto | `PUT /profile/avatar` — multipart, satu file di field `avatar` (jpeg/png/webp, maks 2 MB; server tidak resize). Respons: profil terbaru. |
| Hapus foto | `DELETE /profile/avatar` — respons profil dengan `avatar: ""`; bisa diulang. |
| Lihat foto | `GET /profile/avatar` dengan `Authorization` (byte gambar, ETag). `avatar` di profil adalah path relatif ke host API; `?v=` berubah tiap ganti foto. |
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

## Foto profil di app

- `ProfilePhotoEditor` (layar Ubah Profil): pilih gambar, dikecilkan di app
  (`lib/utils/avatar_image.dart`: tegak, sisi terpanjang 1024 px, JPEG, di bawah 2 MB),
  lalu langsung `PUT /profile/avatar`. Hapus lewat `DELETE`. Form dan foto tidak dikirim
  bersamaan: Simpan mati selama foto diproses, dan foto mati selama form disimpan.
- `UserAvatar` memuat gambar dengan header `Authorization`, hanya untuk host API sendiri.
  Path `avatar` disimpan apa adanya; host ditambahkan saat ditampilkan.
- `AuthProvider.refreshAvatar()` mengambil `avatar` dari `GET /profile` saat dashboard
  dibuka, supaya foto dari perangkat lain muncul.
- 400, 413, 415 menampilkan teks server; 409 dan 422 juga. Akun tanpa data anggota
  (read-only) tidak bisa mengubah foto.
