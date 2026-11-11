# AHPro – Event Organizer & Manajemen Kejuaraan Pencak Silat

Website pendaftaran kejuaraan pencak silat untuk **Al Husna Pro (AHPro)**. Peserta memilih kejuaraan, masuk dengan email, mendaftarkan kontingen dan atlet, mengunggah berkas, lalu membayar. Panitia mengelola kejuaraan dan memverifikasi pendaftaran dari panel admin.

## Fitur

**Peserta**
- Daftar kejuaraan dengan filter status dan pencarian, plus halaman detail (kategori, biaya, kelas tanding, berkas yang diperlukan)
- Login dengan email dan kode (tanpa kata sandi)
- Pendaftaran 4 langkah: kontingen, atlet dan berkas, formulir, pembayaran
- Kelas tanding dipilih dari daftar yang ditetapkan panitia, disarankan otomatis dari berat badan
- Pantau status pendaftaran, lihat kartu pendaftaran setelah terverifikasi

**Admin**
- Tambah, ubah, hapus kejuaraan, termasuk kelas tanding per kelompok usia (Pra Usia Dini 1 sampai Master) untuk putra dan putri
- Periksa pendaftaran, buka berkas, verifikasi atau tolak dengan catatan
- Bagan pertandingan otomatis (sistem gugur untuk Tanding, urutan tampil untuk kategori lain)
- Unduh Excel per kelompok usia (atlet dikelompokkan per kelas, dengan kode kontingen) dan CSV

## Struktur

```
index.html            Seluruh website (HTML, CSS, JavaScript dalam satu file)
supabase/schema.sql   Skema database, aturan keamanan (RLS), dan penyimpanan berkas
docs/panduan-produksi.md   Langkah pemasangan produksi
.nojekyll             Agar GitHub Pages menyajikan file apa adanya
```

## Menjalankan di komputer

Buka `index.html` langsung di browser, atau jalankan server lokal:

```bash
python3 -m http.server 8000
# lalu buka http://localhost:8000
```

## Dua mode

| Mode | Kapan aktif | Data |
|---|---|---|
| **Demo** | `supabaseUrl` dan `supabaseKey` di `CONFIG` masih kosong | Hanya di browser masing-masing, tidak dibagikan antar pengguna |
| **Produksi** | Kedua nilai itu terisi | Tersimpan di Supabase: login email, database, penyimpanan berkas |

Mode demo memakai akun admin `admin@ahpro.id` / `admin123` hanya untuk mencoba tampilan.

## Memasang produksi

Ikuti [docs/panduan-produksi.md](docs/panduan-produksi.md):
1. Buat proyek Supabase, jalankan `supabase/schema.sql`
2. Atur template email (harus memuat `{{ .Token }}`) dan SMTP
3. Isi `supabaseUrl` dan `supabaseKey` di bagian `CONFIG` pada `index.html`
4. Hosting (GitHub Pages, Cloudflare Pages, atau Netlify)
5. Jadikan akun Anda admin lewat SQL

## Hosting dengan GitHub Pages

1. Di repositori: **Settings > Pages**
2. **Source**: Deploy from a branch, branch `main`, folder `/ (root)`
3. Alamat situs: `https://NAMA-AKUN.github.io/NAMA-REPO/`
4. Masukkan alamat itu sebagai **Site URL** di Supabase (**Authentication > URL Configuration**)

Navigasi memakai `#` (misalnya `#/kejuaraan`), jadi berjalan normal di subfolder GitHub Pages.

## Keamanan

- Kunci **anon public** Supabase memang dirancang terlihat di kode website. Keamanan data dijaga oleh aturan RLS di database.
- **Jangan pernah** meng-commit kunci `service_role`, kata sandi database, atau file `.env`.
- Sebelum produksi, kosongkan `adminEmail` dan `adminPass` di `CONFIG` (hanya untuk mode demo).
- Sistem menyimpan data anak dan dokumen identitas. Siapkan kebijakan privasi sebelum dibuka ke publik.

## Teknologi

HTML, CSS, dan JavaScript murni (tanpa build step). Supabase (PostgreSQL, Auth, Storage) untuk produksi, `@supabase/supabase-js` dimuat dari CDN. Pembuatan file Excel dilakukan langsung di browser.

## Catatan pengembangan

- Data kelas tanding bawaan hanyalah contoh. Panitia menetapkan kelas sebenarnya per kejuaraan di panel admin.
- Teks halaman Tentang dan Layanan masih draf, sesuaikan dengan profil AHPro.
- Nomor WhatsApp, email, dan rekening pembayaran di `CONFIG` dan form admin masih placeholder.
