# Panduan memasang AHPro (versi produksi)

Website (`index.html`) sudah siap disambungkan ke Supabase. Anda hanya perlu: **(1)** membuat proyek, **(2)** menjalankan SQL, **(3)** menempel dua nilai, **(4)** mengunggah file ke hosting. Total sekitar 30 menit.

## 1. Buat proyek Supabase

1. Daftar di supabase.com, lalu **New project**. Pilih region **Southeast Asia (Singapore)** dan simpan kata sandi database di tempat aman.
2. Buka **SQL Editor > New query**, tempel seluruh isi `supabase/schema.sql`, klik **Run**. Pastikan tidak ada pesan error.

## 2. Atur login email (kode masuk)

1. **Authentication > Providers > Email**: pastikan Email aktif.
2. **Authentication > Email Templates > Magic Link**: ganti isi pesan agar memuat kode, misalnya:
   ```html
   <h2>Kode masuk AHPro</h2>
   <p>Masukkan kode ini di website: <strong>{{ .Token }}</strong></p>
   <p>Kode berlaku sebentar. Abaikan email ini jika Anda tidak memintanya.</p>
   ```
   (Template harus memuat `{{ .Token }}`, kalau tidak peserta hanya menerima tautan, bukan kode.)
3. **Authentication > SMTP Settings**: pasang SMTP sendiri (misalnya Resend atau Brevo). Pengirim bawaan Supabase sangat dibatasi jumlahnya dan hanya cocok untuk uji coba, jadi pendaftar bisa gagal menerima kode saat ramai.
4. **Authentication > URL Configuration**: isi **Site URL** dengan alamat website Anda setelah langkah 4 (misalnya `https://ahpro.id`).

## 3. Sambungkan website

1. Buka **Project Settings > API**. Salin **Project URL** dan kunci **anon public**.
   **Jangan pernah memakai kunci `service_role` di website.**
2. Buka `index.html` dengan editor teks. Cari bagian `CONFIG` di dekat awal skrip dan isi:
   ```js
   supabaseUrl: 'https://xxxxxxxx.supabase.co',
   supabaseKey: 'eyJ...kunci-anon-public...'
   ```
3. Di `CONFIG` yang sama, kosongkan `adminEmail` dan `adminPass` (hanya dipakai mode demo).

Selama dua baris itu kosong, website berjalan sebagai **demo** (data hanya di browser). Setelah diisi, otomatis menjadi mode produksi.

## 4. Pasang di hosting

Pilih salah satu (gratis untuk skala awal):
- **Cloudflare Pages** > Create > Direct Upload, unggah `index.html`.
- **Netlify** > Add new site > Deploy manually, seret folder berisi `index.html`.
Lalu hubungkan domain Anda dan pastikan HTTPS aktif.

> Website produksi tidak akan berfungsi di pratinjau claude.ai karena pratinjau itu memblokir koneksi ke server lain. Ujilah di hosting Anda.

## 5. Jadikan akun Anda admin

1. Buka website di hosting, masuk lewat menu **Admin** dengan email Anda dan kode dari email.
2. Di Supabase **SQL Editor**, jalankan (ganti emailnya):
   ```sql
   insert into public.admins (user_id)
   select id from auth.users where email = 'email-admin-anda@contoh.com';
   ```
3. Muat ulang halaman Admin. Panel admin sekarang terbuka. Tambahkan kejuaraan pertama Anda.

## 6. Uji sebelum dibuka ke publik

1. Sebagai admin, buat satu kejuaraan uji.
2. Dengan email lain (dan browser mode penyamaran), daftar sebagai peserta: kontingen, atlet, unggah berkas, bukti bayar.
3. Kembali sebagai admin: periksa pendaftaran, buka berkas, verifikasi, undi bagan, unduh Excel.
4. Hapus kejuaraan uji, lalu buat kejuaraan yang sebenarnya.

## Yang masih perlu Anda putuskan

- **Kebijakan privasi dan persetujuan data.** Sistem menyimpan data anak dan dokumen identitas (KK, akta). Berkas disimpan di bucket privat yang hanya bisa dibuka pemilik dan admin, tetapi peserta tetap perlu diberi tahu penggunaan datanya.
- **Pembayaran** masih transfer manual dengan verifikasi admin. Payment gateway (Midtrans/Xendit) bisa ditambahkan nanti.
- **Notifikasi email** saat status berubah belum ada.
- **Cadangan data:** aktifkan backup harian di Supabase.

## Catatan teknis

- Kode kontingen (K001, K002, ...) dibuat otomatis oleh database saat pendaftaran dikirim.
- Peserta tidak bisa mengubah status menjadi terverifikasi, catatan admin, atau data peserta lain. Itu ditegakkan oleh database (RLS dan trigger), bukan oleh tampilan.
- Berkas dibatasi 2 MB dan hanya JPG, PNG, atau PDF.
