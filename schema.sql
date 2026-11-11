-- =====================================================================
-- AHPro – skema database Supabase (PostgreSQL) – VERSI PRODUKSI
-- Jalankan di Supabase: SQL Editor > New query > paste semua > Run
-- Aman dijalankan pada proyek BARU yang masih kosong.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- Admin ----------
create table public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

-- ---------- Kejuaraan ----------
create table public.championships (
  id               uuid primary key default gen_random_uuid(),
  nama             text not null,
  tanggal_mulai    date not null,
  tanggal_selesai  date not null,
  deadline         date not null,
  lokasi           text not null,
  kota             text not null,
  deskripsi        text not null default '',
  status           text not null default 'buka' check (status in ('buka','tutup','selesai')),
  kategori         text[] not null,
  fees             jsonb  not null default '{}',
  kelompok_usia    text[] not null,
  kelas_tanding    jsonb  not null default '{}',   -- {"Usia Dini 1":{"Putra":[{"n":"A","a":20,"b":23}],"Putri":[...]}}
  berkas           text[] not null,
  pembayaran       jsonb  not null default '[]',   -- [{"metode":"Transfer bank","detail":"..."}]
  created_at       timestamptz not null default now(),
  check (tanggal_selesai >= tanggal_mulai),
  check (deadline <= tanggal_mulai)
);

-- ---------- Pendaftaran (satu kontingen per akun per kejuaraan) ----------
create table public.registrations (
  id                 uuid primary key default gen_random_uuid(),
  championship_id    uuid not null references public.championships(id) on delete cascade,
  user_id            uuid not null default auth.uid() references auth.users(id) on delete cascade,
  email              text not null default (auth.jwt() ->> 'email'),
  kontingen_nama     text not null default '',
  asal               text not null default '',
  manajer            text not null default '',
  hp                 text not null default '',
  pernyataan_setuju  boolean not null default false,
  penanggung_jawab   text not null default '',
  status             text not null default 'draft'
                     check (status in ('draft','menunggu_verifikasi','terverifikasi','ditolak')),
  catatan            text not null default '',
  metode_bayar       text,
  kode_unik          int  not null default (100 + floor(random() * 900))::int,
  pengirim           text,
  tgl_bayar          date,
  bukti_path         text,                         -- path di Storage bucket "berkas"
  kode_kontingen     text,                         -- K001, K002, ... otomatis saat dikirim
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (championship_id, user_id),
  unique (championship_id, kode_kontingen)
);

-- ---------- Atlet ----------
create table public.athletes (
  id               uuid primary key default gen_random_uuid(),
  registration_id  uuid not null references public.registrations(id) on delete cascade,
  nama             text not null,
  jk               text not null check (jk in ('Putra','Putri')),
  tgl_lahir        date not null check (tgl_lahir <= current_date),
  bb               numeric(4,1) not null check (bb between 10 and 150),
  sekolah          text not null,
  kategori         text not null,
  usia             text not null,
  kelas            text not null,
  anggota          text not null default '',
  berkas           jsonb not null default '{}',    -- {"Foto atlet 3x4":{"n":"foto.jpg","s":12345,"p":"<path Storage>"}}
  created_at       timestamptz not null default now()
);

-- ---------- Bagan pertandingan (hasil undian, khusus admin) ----------
create table public.bagan (
  championship_id  uuid not null references public.championships(id) on delete cascade,
  group_key        text not null,
  data             jsonb not null,
  updated_at       timestamptz not null default now(),
  primary key (championship_id, group_key)
);

create index on public.registrations (championship_id);
create index on public.registrations (user_id);
create index on public.athletes (registration_id);

-- ---------- Trigger: kolom milik admin dilindungi + kode kontingen otomatis ----------
create or replace function public.guard_registration_update()
returns trigger language plpgsql security definer set search_path = public as $$
declare n int;
begin
  new.updated_at := now();
  if not public.is_admin() then
    new.catatan         := old.catatan;
    new.kode_unik       := old.kode_unik;
    new.kode_kontingen  := old.kode_kontingen;
    new.user_id         := old.user_id;
    new.championship_id := old.championship_id;
    -- peserta hanya boleh: draft/ditolak -> draft/menunggu_verifikasi
    if new.status is distinct from old.status
       and not (old.status in ('draft','ditolak') and new.status in ('draft','menunggu_verifikasi')) then
      raise exception 'Perubahan status tidak diizinkan';
    end if;
  end if;
  if new.status <> 'draft' and new.kode_kontingen is null then
    perform pg_advisory_xact_lock(hashtext(new.championship_id::text));
    select coalesce(max(substring(kode_kontingen from 2)::int), 0) + 1 into n
      from public.registrations
     where championship_id = new.championship_id and kode_kontingen is not null;
    new.kode_kontingen := 'K' || lpad(n::text, 3, '0');
  end if;
  return new;
end $$;

create trigger trg_guard_registration
before update on public.registrations
for each row execute function public.guard_registration_update();

-- ---------- Row Level Security ----------
alter table public.admins         enable row level security;
alter table public.championships  enable row level security;
alter table public.registrations  enable row level security;
alter table public.athletes       enable row level security;
alter table public.bagan          enable row level security;

create policy admins_select on public.admins for select using (public.is_admin());

create policy champ_read  on public.championships for select using (true);
create policy champ_admin on public.championships for all
  using (public.is_admin()) with check (public.is_admin());

create policy reg_owner_select on public.registrations for select
  using (user_id = auth.uid() or public.is_admin());
create policy reg_owner_insert on public.registrations for insert
  with check (user_id = auth.uid() and status = 'draft');
create policy reg_owner_update on public.registrations for update
  using ((user_id = auth.uid() and status in ('draft','ditolak')) or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());
create policy reg_admin_delete on public.registrations for delete using (public.is_admin());

create policy ath_select on public.athletes for select using (
  public.is_admin() or exists (select 1 from public.registrations r
    where r.id = registration_id and r.user_id = auth.uid()));
create policy ath_write on public.athletes for all using (
  public.is_admin() or exists (select 1 from public.registrations r
    where r.id = registration_id and r.user_id = auth.uid() and r.status in ('draft','ditolak')))
with check (
  public.is_admin() or exists (select 1 from public.registrations r
    where r.id = registration_id and r.user_id = auth.uid() and r.status in ('draft','ditolak')));

create policy bagan_admin on public.bagan for all
  using (public.is_admin()) with check (public.is_admin());

-- ---------- Storage: bucket privat untuk berkas & bukti bayar ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('berkas', 'berkas', false, 2097152,
        array['image/jpeg','image/png','application/pdf'])
on conflict (id) do nothing;

-- Struktur path: {user_id}/{registration_id}/{nama-file}
create policy berkas_owner_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'berkas' and (storage.foldername(name))[1] = auth.uid()::text);
create policy berkas_owner_update on storage.objects for update to authenticated
  using (bucket_id = 'berkas' and (storage.foldername(name))[1] = auth.uid()::text);
create policy berkas_owner_select on storage.objects for select to authenticated
  using (bucket_id = 'berkas' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));
create policy berkas_owner_delete on storage.objects for delete to authenticated
  using (bucket_id = 'berkas' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

-- =====================================================================
-- LANGKAH TERAKHIR (jalankan SETELAH Anda login sekali di website dengan email admin):
--   insert into public.admins (user_id)
--   select id from auth.users where email = 'EMAIL-ADMIN-ANDA@contoh.com';
-- =====================================================================
