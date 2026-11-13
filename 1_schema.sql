-- ============================================================
-- CountriesGuessor · онлайн · схема базы Supabase
-- Запуск: Supabase → SQL Editor → New query → вставить → Run.
-- Скрипт можно запускать повторно (он ничего не удаляет).
-- Все таблицы называются cg_*, старые таблицы profiles/friendships/rooms
-- из прошлой заготовки не затрагиваются.
-- ============================================================

-- ---------- 1. Таблицы ----------

create table if not exists public.cg_profiles (
  id             uuid primary key references auth.users(id) on delete cascade,
  username       text not null,
  username_lower text not null unique,
  look           jsonb,                       -- внешний вид персонажа
  title          text,                        -- активный титул
  last_seen      timestamptz not null default now(),
  created_at     timestamptz not null default now()
);

create table if not exists public.cg_friendships (
  id         bigint generated always as identity primary key,
  requester  uuid not null references public.cg_profiles(id) on delete cascade,
  addressee  uuid not null references public.cg_profiles(id) on delete cascade,
  status     text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  check (requester <> addressee)
);
-- одна пара игроков = одна запись, независимо от направления
create unique index if not exists cg_friendships_pair
  on public.cg_friendships (least(requester, addressee), greatest(requester, addressee));
create index if not exists cg_friendships_req on public.cg_friendships (requester);
create index if not exists cg_friendships_adr on public.cg_friendships (addressee);

-- база названий для проверки ходов на сервере (заполняется 2_entities.sql)
create table if not exists public.cg_entities (
  id     int primary key,
  ukey   text not null unique,   -- нормализованное название
  name   text not null,          -- как показывать
  kind   text not null,          -- c страна, t территория, y город
  first  text not null,          -- первая буква основного названия
  firsts text not null,          -- первые буквы всех допустимых названий (включая синонимы)
  cands  text not null           -- буквы названия с конца: кандидаты «следующей буквы»
);
create index if not exists cg_entities_first on public.cg_entities (first);

create table if not exists public.cg_matches (
  id         uuid primary key default gen_random_uuid(),
  host       uuid not null references public.cg_profiles(id) on delete cascade,
  guest      uuid references public.cg_profiles(id) on delete cascade,
  mode       text not null check (mode in ('countries','cities','mixed')),
  timed      boolean not null default true,
  status     text not null default 'waiting'
             check (status in ('waiting','playing','finished','declined','cancelled')),
  invited    boolean not null default false,  -- true: приглашение другу, false: быстрый поиск
  cur        uuid,                            -- чей сейчас ход
  letter     text,                            -- нужная буква
  turn       int not null default 1,
  deadline   timestamptz,                     -- серверный дедлайн хода
  used       text[] not null default '{}',    -- уже названные объекты (ukey)
  last_name  text,
  last_by    uuid,
  fallback   boolean not null default false,  -- буква сменилась из-за нехватки ответов
  host_n     int not null default 0,
  guest_n    int not null default 0,
  winner     uuid,
  reason     text,                            -- timeout | exhausted | left
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists cg_matches_host  on public.cg_matches (host);
create index if not exists cg_matches_guest on public.cg_matches (guest);
create index if not exists cg_matches_open  on public.cg_matches (status, invited, created_at);

-- ---------- 2. Права и RLS ----------

alter table public.cg_profiles    enable row level security;
alter table public.cg_friendships enable row level security;
alter table public.cg_entities    enable row level security;
alter table public.cg_matches     enable row level security;

revoke all on public.cg_profiles    from anon, authenticated;
revoke all on public.cg_friendships from anon, authenticated;
revoke all on public.cg_entities    from anon, authenticated;
revoke all on public.cg_matches     from anon, authenticated;

grant select on public.cg_profiles    to authenticated;
grant update (look, title, last_seen) on public.cg_profiles to authenticated;
grant select on public.cg_friendships to authenticated;
grant select on public.cg_matches     to authenticated;

drop policy if exists cg_profiles_read on public.cg_profiles;
create policy cg_profiles_read on public.cg_profiles
  for select to authenticated using (true);

drop policy if exists cg_profiles_upd on public.cg_profiles;
create policy cg_profiles_upd on public.cg_profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

drop policy if exists cg_friendships_read on public.cg_friendships;
create policy cg_friendships_read on public.cg_friendships
  for select to authenticated
  using ((select auth.uid()) in (requester, addressee));

drop policy if exists cg_matches_read on public.cg_matches;
create policy cg_matches_read on public.cg_matches
  for select to authenticated
  using ((select auth.uid()) in (host, guest));

-- Писать в cg_friendships / cg_matches / cg_entities напрямую нельзя:
-- все изменения идут только через функции ниже (они проверяют правила на сервере).

-- ---------- 3. Вспомогательные функции ----------

create or replace function public.cg_mode_ok(p_mode text, p_kind text)
returns boolean language sql immutable as $$
  select p_mode = 'mixed' or ((p_mode = 'cities') = (p_kind = 'y'))
$$;

-- лимит хода: 120 / 60 / 30 секунд; без таймера — 10 минут «ушёл из игры»
create or replace function public.cg_limit(p_turn int, p_timed boolean)
returns int language sql immutable as $$
  select case when not p_timed then 600
              when p_turn <= 30 then 120
              when p_turn <= 60 then 60
              else 30 end
$$;

create or replace function public.cg_start_match(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update cg_matches set
    status = 'playing',
    cur = case when random() < 0.5 then host else guest end,
    turn = 1, letter = null, used = '{}', host_n = 0, guest_n = 0,
    fallback = false, last_name = null, last_by = null,
    deadline = now() + make_interval(secs => cg_limit(1, timed) + 5),  -- +5 с на «рулетку»
    updated_at = now()
  where id = p_id;
end $$;
revoke all on function public.cg_start_match(uuid) from public, anon, authenticated;

-- ---------- 4. Профиль ----------

create or replace function public.cg_register(p_username text, p_look jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_username !~ '^[A-Za-z0-9_А-Яа-яЁё-]{3,20}$' then raise exception 'bad username'; end if;
  insert into cg_profiles (id, username, username_lower, look)
  values (auth.uid(), p_username, lower(p_username), p_look)
  on conflict (id) do nothing;
exception when unique_violation then
  raise exception 'username taken';
end $$;

-- ---------- 5. Друзья ----------

create or replace function public.cg_friend_request(p_username text)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  t uuid;
  ex public.cg_friendships%rowtype;
begin
  if me is null then raise exception 'not authenticated'; end if;
  select id into t from cg_profiles where username_lower = lower(trim(p_username));
  if t is null then return 'not_found'; end if;
  if t = me then return 'self'; end if;
  select * into ex from cg_friendships
   where least(requester, addressee) = least(me, t)
     and greatest(requester, addressee) = greatest(me, t);
  if found then
    if ex.status = 'accepted' then return 'already'; end if;
    if ex.addressee = me then
      update cg_friendships set status = 'accepted' where id = ex.id;  -- встречная заявка
      return 'accepted';
    end if;
    return 'pending';
  end if;
  insert into cg_friendships (requester, addressee) values (me, t);
  return 'sent';
end $$;

create or replace function public.cg_friend_respond(p_id bigint, p_accept boolean)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_accept then
    update cg_friendships set status = 'accepted'
     where id = p_id and addressee = auth.uid() and status = 'pending';
  else
    delete from cg_friendships
     where id = p_id and addressee = auth.uid() and status = 'pending';
  end if;
  return found;
end $$;

-- удалить из друзей / отозвать свою заявку
create or replace function public.cg_friend_remove(p_id bigint)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from cg_friendships where id = p_id and auth.uid() in (requester, addressee);
  return found;
end $$;

-- ---------- 6. Лобби и матчи ----------

-- быстрый поиск: подключает к чужому ожидающему матчу или создаёт свой
create or replace function public.cg_find_match(p_mode text, p_timed boolean)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  m public.cg_matches%rowtype;
  nid uuid;
begin
  if me is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from cg_profiles where id = me) then raise exception 'no profile'; end if;
  if p_mode not in ('countries','cities','mixed') then raise exception 'bad mode'; end if;

  update cg_matches set status = 'cancelled', updated_at = now()
   where host = me and status = 'waiting';

  select * into m from cg_matches
   where status = 'waiting' and invited = false and guest is null
     and host <> me and mode = p_mode and timed = p_timed
     and created_at > now() - interval '2 minutes'
   order by created_at
   limit 1
   for update skip locked;

  if found then
    update cg_matches set guest = me where id = m.id;
    perform cg_start_match(m.id);
    return m.id;
  end if;

  insert into cg_matches (host, mode, timed) values (me, p_mode, p_timed) returning id into nid;
  return nid;
end $$;

-- приглашение друга в матч
create or replace function public.cg_invite(p_friend uuid, p_mode text, p_timed boolean)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); nid uuid;
begin
  if me is null then raise exception 'not authenticated'; end if;
  if p_mode not in ('countries','cities','mixed') then raise exception 'bad mode'; end if;
  if not exists (
    select 1 from cg_friendships
     where status = 'accepted'
       and ((requester = me and addressee = p_friend) or (requester = p_friend and addressee = me))
  ) then raise exception 'not friends'; end if;

  update cg_matches set status = 'cancelled', updated_at = now()
   where host = me and status = 'waiting';

  insert into cg_matches (host, guest, mode, timed, invited)
  values (me, p_friend, p_mode, p_timed, true) returning id into nid;
  return nid;
end $$;

create or replace function public.cg_accept_match(p_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); m public.cg_matches%rowtype;
begin
  if me is null then raise exception 'not authenticated'; end if;
  select * into m from cg_matches
   where id = p_id and guest = me and status = 'waiting' and invited for update;
  if not found or m.created_at < now() - interval '10 minutes' then return false; end if;
  perform cg_start_match(p_id);
  return true;
end $$;

create or replace function public.cg_decline_match(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update cg_matches set status = 'declined', updated_at = now()
   where id = p_id and guest = auth.uid() and status = 'waiting';
end $$;

create or replace function public.cg_cancel_match(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update cg_matches set status = 'cancelled', updated_at = now()
   where id = p_id and host = auth.uid() and status = 'waiting';
end $$;

-- ход: ВСЕ правила проверяются здесь, на сервере
create or replace function public.cg_submit_move(p_match uuid, p_ukey text)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  m public.cg_matches%rowtype;
  e public.cg_entities%rowtype;
  v_key text := left(coalesce(p_ukey, ''), 120);
  other uuid;
  nxt text;
  fb boolean := false;
  i int;
begin
  select * into m from cg_matches where id = p_match for update;
  if not found or (me is distinct from m.host and me is distinct from m.guest) then
    return 'forbidden';
  end if;
  if m.status <> 'playing' then return 'over'; end if;
  if m.cur is distinct from me then return 'not_your_turn'; end if;
  other := case when m.host = me then m.guest else m.host end;

  if m.deadline is not null and now() > m.deadline then
    update cg_matches set status = 'finished', winner = other, reason = 'timeout', updated_at = now()
     where id = p_match;
    return 'timeout';
  end if;

  select * into e from cg_entities
   where ukey = v_key and cg_mode_ok(m.mode, kind)
   limit 1;
  if not found then return 'not_found'; end if;
  if v_key = any (m.used) then return 'used'; end if;
  if m.letter is not null and position(m.letter in e.firsts) = 0 then return 'wrong_letter'; end if;

  m.used := array_append(m.used, v_key);

  -- следующая буква: с конца названия, пропуская буквы без свободных ответов
  for i in 1 .. length(e.cands) loop
    if exists (
      select 1 from cg_entities x
       where x.first = substr(e.cands, i, 1)
         and cg_mode_ok(m.mode, x.kind)
         and not (x.ukey = any (m.used))
    ) then
      nxt := substr(e.cands, i, 1);
      fb := (i > 1);
      exit;
    end if;
  end loop;

  if nxt is null then
    update cg_matches set
      used = m.used, last_name = e.name, last_by = me,
      host_n  = host_n  + (case when me = host  then 1 else 0 end),
      guest_n = guest_n + (case when me = guest then 1 else 0 end),
      status = 'finished', winner = me, reason = 'exhausted', updated_at = now()
     where id = p_match;
    return 'ok';
  end if;

  update cg_matches set
    used = m.used, letter = nxt, fallback = fb,
    turn = m.turn + 1, cur = other,
    deadline = now() + make_interval(secs => cg_limit(m.turn + 1, timed)),
    last_name = e.name, last_by = me,
    host_n  = host_n  + (case when me = host  then 1 else 0 end),
    guest_n = guest_n + (case when me = guest then 1 else 0 end),
    updated_at = now()
   where id = p_match;
  return 'ok';
end $$;

-- время хода истекло: может вызвать любой из двух игроков
create or replace function public.cg_claim_timeout(p_match uuid)
returns text language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); m public.cg_matches%rowtype;
begin
  select * into m from cg_matches where id = p_match for update;
  if not found or (me is distinct from m.host and me is distinct from m.guest) then return 'forbidden'; end if;
  if m.status <> 'playing' then return 'over'; end if;
  if m.deadline is null or now() < m.deadline then return 'early'; end if;
  update cg_matches set
    status = 'finished',
    winner = case when cur = host then guest else host end,
    reason = 'timeout', updated_at = now()
   where id = p_match;
  return 'ok';
end $$;

create or replace function public.cg_resign(p_match uuid)
returns text language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); m public.cg_matches%rowtype;
begin
  select * into m from cg_matches where id = p_match for update;
  if not found or (me is distinct from m.host and me is distinct from m.guest) then return 'forbidden'; end if;
  if m.status = 'waiting' then
    if m.host = me then
      update cg_matches set status = 'cancelled', updated_at = now() where id = p_match;
    end if;
    return 'ok';
  end if;
  if m.status <> 'playing' then return 'over'; end if;
  update cg_matches set
    status = 'finished',
    winner = case when m.host = me then guest else host end,
    reason = 'left', updated_at = now()
   where id = p_match;
  return 'ok';
end $$;

create or replace function public.cg_server_time()
returns timestamptz language sql stable as $$ select now() $$;

-- ---------- 7. Доступ к функциям: только для вошедших игроков ----------

do $$
declare f text;
begin
  foreach f in array array[
    'cg_register(text,jsonb)',
    'cg_friend_request(text)',
    'cg_friend_respond(bigint,boolean)',
    'cg_friend_remove(bigint)',
    'cg_find_match(text,boolean)',
    'cg_invite(uuid,text,boolean)',
    'cg_accept_match(uuid)',
    'cg_decline_match(uuid)',
    'cg_cancel_match(uuid)',
    'cg_submit_move(uuid,text)',
    'cg_claim_timeout(uuid)',
    'cg_resign(uuid)',
    'cg_server_time()'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ---------- 8. Realtime ----------

do $$
begin
  begin alter publication supabase_realtime add table public.cg_matches;
  exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.cg_friendships;
  exception when duplicate_object then null; end;
end $$;

select 'Схема готова. Теперь запустите 2_entities.sql' as next_step;
