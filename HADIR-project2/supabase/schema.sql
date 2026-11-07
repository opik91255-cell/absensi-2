create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null default '',
  student_number text unique,
  role text not null default 'participant' check (role in ('admin','participant')),
  qr_token text not null unique default encode(gen_random_bytes(24), 'hex'),
  created_at timestamptz not null default now()
);

create table if not exists public.attendance_sessions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  session_date date not null default current_date,
  is_open boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.profiles(id) on delete cascade,
  session_id uuid not null references public.attendance_sessions(id) on delete cascade,
  checked_at timestamptz not null default now(),
  status text not null default 'Hadir' check (status in ('Hadir')),
  unique(participant_id, session_id)
);

create index if not exists attendance_session_idx on public.attendance(session_id);
create index if not exists attendance_participant_idx on public.attendance(participant_id);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles(id,email,full_name,student_number,role)
  values (
    new.id,
    coalesce(new.email,''),
    coalesce(new.raw_user_meta_data->>'full_name',''),
    nullif(new.raw_user_meta_data->>'student_number',''),
    'participant'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public
as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

alter table public.profiles enable row level security;
alter table public.attendance_sessions enable row level security;
alter table public.attendance enable row level security;

create policy "profiles read self or admin" on public.profiles
for select to authenticated using (id = auth.uid() or public.is_admin());
create policy "admin update profiles" on public.profiles
for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin delete profiles" on public.profiles
for delete to authenticated using (public.is_admin());

create policy "sessions read authenticated" on public.attendance_sessions
for select to authenticated using (true);
create policy "admin create sessions" on public.attendance_sessions
for insert to authenticated with check (public.is_admin());
create policy "admin update sessions" on public.attendance_sessions
for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin delete sessions" on public.attendance_sessions
for delete to authenticated using (public.is_admin());

create policy "attendance read own or admin" on public.attendance
for select to authenticated using (participant_id = auth.uid() or public.is_admin());

-- Tidak ada policy INSERT/UPDATE/DELETE untuk peserta maupun browser admin.
-- Pencatatan hadir hanya lewat fungsi RPC admin_checkin.
create or replace function public.admin_checkin(p_qr_token text, p_session_id uuid)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare
  v_participant public.profiles%rowtype;
  v_session public.attendance_sessions%rowtype;
begin
  if not public.is_admin() then
    return jsonb_build_object('ok',false,'message','Akses ditolak. Hanya admin yang boleh memindai.');
  end if;

  select * into v_session from public.attendance_sessions where id = p_session_id;
  if not found or not v_session.is_open then
    return jsonb_build_object('ok',false,'message','Sesi tidak ditemukan atau sudah ditutup.');
  end if;

  select * into v_participant from public.profiles
  where qr_token = p_qr_token and role = 'participant';
  if not found then
    return jsonb_build_object('ok',false,'message','QR tidak dikenal.');
  end if;

  insert into public.attendance(participant_id,session_id)
  values(v_participant.id,v_session.id)
  on conflict(participant_id,session_id) do nothing;

  if found then
    return jsonb_build_object('ok',true,'message','Absensi berhasil untuk '||v_participant.full_name||'.');
  end if;
  return jsonb_build_object('ok',false,'message','Peserta ini sudah tercatat hadir pada sesi tersebut.');
end;
$$;

revoke all on function public.admin_checkin(text,uuid) from public;
grant execute on function public.admin_checkin(text,uuid) to authenticated;

grant usage on schema public to authenticated;
grant select on public.profiles, public.attendance_sessions, public.attendance to authenticated;
grant update, delete on public.profiles to authenticated;
grant insert, update, delete on public.attendance_sessions to authenticated;


-- Admin dapat membuat token QR baru. Token lama langsung tidak berlaku.
create or replace function public.admin_reset_qr(p_participant_id uuid)
returns text language plpgsql security definer set search_path = public
as $$
declare v_token text;
begin
  if not public.is_admin() then raise exception 'Akses ditolak.'; end if;
  update public.profiles set qr_token = encode(gen_random_bytes(24), 'hex')
  where id = p_participant_id and role = 'participant'
  returning qr_token into v_token;
  if v_token is null then raise exception 'Peserta tidak ditemukan.'; end if;
  return v_token;
end;
$$;
revoke all on function public.admin_reset_qr(uuid) from public;
grant execute on function public.admin_reset_qr(uuid) to authenticated;

create policy "admin delete attendance" on public.attendance
for delete to authenticated using (public.is_admin());
