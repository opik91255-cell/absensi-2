-- HADIR One QR: jalankan SEKALI setelah schema.sql lama berhasil dibuat.
-- QR sesi disimpan terpisah agar peserta tidak bisa membaca token semua sesi.
create extension if not exists pgcrypto;
create table if not exists public.session_qr_tokens (
  session_id uuid primary key references public.attendance_sessions(id) on delete cascade,
  token text not null unique default encode(gen_random_bytes(24), 'hex'),
  created_at timestamptz not null default now()
);
alter table public.session_qr_tokens enable row level security;
drop policy if exists "admin read session qr" on public.session_qr_tokens;
create policy "admin read session qr" on public.session_qr_tokens
for select to authenticated using (public.is_admin());
revoke all on public.session_qr_tokens from anon, authenticated;
grant select on public.session_qr_tokens to authenticated;

create or replace function public.issue_session_qr()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.session_qr_tokens(session_id) values (new.id)
  on conflict (session_id) do nothing;
  if tg_op = 'UPDATE' and new.is_open and not old.is_open then
    update public.session_qr_tokens
       set token = encode(gen_random_bytes(24), 'hex'), created_at = now()
     where session_id = new.id;
  end if;
  return new;
end;
$$;
drop trigger if exists issue_session_qr_insert on public.attendance_sessions;
create trigger issue_session_qr_insert after insert on public.attendance_sessions
for each row execute function public.issue_session_qr();
drop trigger if exists issue_session_qr_reopen on public.attendance_sessions;
create trigger issue_session_qr_reopen after update of is_open on public.attendance_sessions
for each row execute function public.issue_session_qr();
insert into public.session_qr_tokens(session_id)
select id from public.attendance_sessions on conflict(session_id) do nothing;

-- Melihat detail sesi dari QR tanpa membocorkan token sesi lain.
create or replace function public.preview_session_qr(p_token text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare s public.attendance_sessions%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok',false,'message','Silakan login dahulu.');
  end if;
  select a.* into s from public.attendance_sessions a
  join public.session_qr_tokens q on q.session_id=a.id
  where q.token=p_token and a.is_open=true;
  if not found then
    return jsonb_build_object('ok',false,'message','QR tidak valid atau sesi sudah ditutup.');
  end if;
  return jsonb_build_object('ok',true,'title',s.title,'session_date',s.session_date);
end;
$$;
revoke all on function public.preview_session_qr(text) from public;
grant execute on function public.preview_session_qr(text) to authenticated;

-- Pencatatan hadir selalu memakai auth.uid(), bukan ID yang dikirim browser.
create or replace function public.participant_checkin(p_token text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_id uuid; v_title text; v_user uuid := auth.uid();
begin
  if v_user is null then
    return jsonb_build_object('ok',false,'message','Silakan login dahulu.');
  end if;
  if not exists(select 1 from public.profiles where id=v_user and role='participant') then
    return jsonb_build_object('ok',false,'message','Hanya akun peserta yang bisa absen.');
  end if;
  select a.id, a.title into v_id, v_title
  from public.attendance_sessions a
  join public.session_qr_tokens q on q.session_id=a.id
  where q.token=p_token and a.is_open=true;
  if v_id is null then
    return jsonb_build_object('ok',false,'message','QR tidak valid atau sesi sudah ditutup.');
  end if;
  insert into public.attendance(participant_id, session_id)
  values (v_user, v_id) on conflict(participant_id, session_id) do nothing;
  if found then
    return jsonb_build_object('ok',true,'message','Berhasil absen di '||v_title||'.');
  end if;
  return jsonb_build_object('ok',false,'message','Kamu sudah absen pada sesi ini.');
end;
$$;
revoke all on function public.participant_checkin(text) from public;
grant execute on function public.participant_checkin(text) to authenticated;
