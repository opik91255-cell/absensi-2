-- HADIR: username peserta, tanpa NIM/email/nomor identitas di formulir peserta.
-- Jalankan satu kali setelah schema.sql dan migration_one_qr.sql.

alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists class_name text not null default '';
create unique index if not exists profiles_username_lower_uidx
  on public.profiles (lower(username)) where username is not null;

-- Profil baru dibuat oleh trigger Auth. Email internal hanya dipakai sebagai identitas teknis Auth;
-- peserta tidak diminta memasukkan atau melihat alamat email. Admin tetap memakai email asli.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public, auth, pg_temp
as $$
begin
  insert into public.profiles(id,email,full_name,role,username,class_name)
  values (new.id, coalesce(new.email,''),
    coalesce(new.raw_user_meta_data->>'full_name',''), 'participant',
    nullif(lower(new.raw_user_meta_data->>'username'),''),
    coalesce(new.raw_user_meta_data->>'class_name',''))
  on conflict (id) do update set
    full_name=excluded.full_name,
    username=coalesce(excluded.username,public.profiles.username),
    class_name=excluded.class_name;
  return new;
end;
$$;

-- Daftar teman hanya berisi nama, kelas tidak perlu ditampilkan berulang, waktu, dan status.
create or replace function public.class_attendance(p_session_id uuid)
returns table(full_name text, checked_at timestamptz, status text)
language plpgsql stable security definer set search_path = public, auth, pg_temp
as $$
begin
  if auth.uid() is null or not exists (select 1 from public.profiles p where p.id=auth.uid() and p.role='participant') then
    raise exception 'Akses hanya untuk peserta yang login.';
  end if;
  if not exists (select 1 from public.attendance a where a.session_id=p_session_id and a.participant_id=auth.uid()) then
    raise exception 'Kamu harus tercatat hadir pada sesi ini untuk melihat daftar kehadiran kelas.';
  end if;
  return query
    select p.full_name, a.checked_at, a.status
    from public.attendance a join public.profiles p on p.id=a.participant_id
    where a.session_id=p_session_id
    order by p.full_name;
end;
$$;
revoke all on function public.class_attendance(uuid) from public;
grant execute on function public.class_attendance(uuid) to authenticated;

notify pgrst, 'reload schema';
