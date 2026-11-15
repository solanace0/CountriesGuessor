-- =====================================================================
-- CountriesGuessor · режим «Столицы» — всё в ОДНОМ файле.
-- Заменяет 3_capitals.sql + 4_lobby.sql + 5_repair.sql для этого режима.
-- Как запустить: Supabase → SQL Editor → New query → вставить ВЕСЬ текст → Run.
-- Можно запускать повторно. После запуска внизу появится таблица: везде должно быть OK.
-- =====================================================================

-- 0. Колонка премиума в профилях (её пишет клиент)
alter table public.cg_profiles add column if not exists prem boolean not null default false;
-- права клиента на обновление своего профиля (из-за их отсутствия онлайн писал «профиль не сохранён»)
do $do$ begin
  execute 'grant update (look, title, last_seen, prem) on public.cg_profiles to authenticated';
exception when others then null;
end $do$;

-- 1. Нормализация ответа: регистр, ё/е, пробелы, дефисы и знаки не важны
create or replace function public.cg_norm(t text) returns text
language sql immutable as $$
  select regexp_replace(
    replace(lower(translate(coalesce(t,''),
      'АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯІЇЄҐ',
      'абвгдеёжзийклмнопрстуфхцчшщъыьэюяіїєґ')),'ё','е'),
    '[^a-z0-9а-яіїєґ]+','','g')
$$;

-- 2. Столицы (ключ — код страны, как у флагов в игре)
create table if not exists public.cg_capitals (
  iso  text primary key,
  cap  text not null,
  alts text[] not null default '{}'
);
alter table public.cg_capitals enable row level security;

insert into public.cg_capitals (iso, cap, alts) values
  ('AT','Вена','{"Vienna","Wien"}'),
  ('BE','Брюссель','{"Brussels"}'),
  ('BG','София','{"Sofia"}'),
  ('BA','Сараево','{"Sarajevo"}'),
  ('GB','Лондон','{"London"}'),
  ('HU','Будапешт','{"Budapest"}'),
  ('DE','Берлин','{"Berlin"}'),
  ('GR','Афины','{"Athens"}'),
  ('DK','Копенгаген','{"Copenhagen"}'),
  ('IE','Дублин','{"Dublin"}'),
  ('IS','Рейкьявик','{"Reykjavik"}'),
  ('ES','Мадрид','{"Madrid"}'),
  ('IT','Рим','{"Rome"}'),
  ('LV','Рига','{"Riga"}'),
  ('LT','Вильнюс','{"Vilnius"}'),
  ('LU','Люксембург','{"Luxembourg"}'),
  ('MD','Кишинёв','{"Chisinau"}'),
  ('MC','Монако','{"Monaco"}'),
  ('NL','Амстердам','{"Amsterdam"}'),
  ('NO','Осло','{"Oslo"}'),
  ('PL','Варшава','{"Warsaw"}'),
  ('PT','Лиссабон','{"Lisbon"}'),
  ('RU','Москва','{"Moscow"}'),
  ('RO','Бухарест','{"Bucharest"}'),
  ('MK','Скопье','{"Skopje"}'),
  ('RS','Белград','{"Belgrade"}'),
  ('SK','Братислава','{"Bratislava"}'),
  ('SI','Любляна','{"Ljubljana"}'),
  ('UA','Киев','{"Київ","Kyiv","Kiev"}'),
  ('FI','Хельсинки','{"Helsinki"}'),
  ('FR','Париж','{"Paris"}'),
  ('HR','Загреб','{"Zagreb"}'),
  ('CZ','Прага','{"Prague"}'),
  ('CH','Берн','{"Bern"}'),
  ('SE','Стокгольм','{"Stockholm"}'),
  ('EE','Таллин','{"Таллинн","Tallinn"}'),
  ('AZ','Баку','{"Baku"}'),
  ('AM','Ереван','{"Yerevan"}'),
  ('BD','Дакка','{"Дхака","Dhaka"}'),
  ('VN','Ханой','{"Hanoi"}'),
  ('GE','Тбилиси','{"Tbilisi"}'),
  ('IL','Иерусалим','{"Jerusalem"}'),
  ('IN','Нью-Дели','{"Дели","New Delhi","Delhi"}'),
  ('ID','Джакарта','{"Jakarta"}'),
  ('JO','Амман','{"Amman"}'),
  ('IR','Тегеран','{"Tehran"}'),
  ('YE','Сана','{"Санаа","Sanaa"}'),
  ('KG','Бишкек','{"Bishkek"}'),
  ('CN','Пекин','{"Beijing"}'),
  ('KP','Пхеньян','{"Pyongyang"}'),
  ('KR','Сеул','{"Seoul"}'),
  ('KW','Эль-Кувейт','{"Кувейт","Kuwait City"}'),
  ('LA','Вьентьян','{"Vientiane"}'),
  ('MY','Куала-Лумпур','{"Kuala Lumpur"}'),
  ('MM','Нейпьидо','{"Нейпидо","Ней Пьи Тоу","Naypyidaw"}'),
  ('AE','Абу-Даби','{"Abu Dhabi"}'),
  ('PK','Исламабад','{"Islamabad"}'),
  ('PS','Рамалла','{"Восточный Иерусалим","Иерусалим","Ramallah"}'),
  ('SG','Сингапур','{"Singapore"}'),
  ('SY','Дамаск','{"Damascus"}'),
  ('TJ','Душанбе','{"Dushanbe"}'),
  ('TH','Бангкок','{"Bangkok"}'),
  ('TR','Анкара','{"Ankara"}'),
  ('UZ','Ташкент','{"Tashkent"}'),
  ('PH','Манила','{"Manila"}'),
  ('JP','Токио','{"Tokyo"}'),
  ('DZ','Алжир','{"Algiers"}'),
  ('BW','Габороне','{"Gaborone"}'),
  ('GA','Либревиль','{"Libreville"}'),
  ('GH','Аккра','{"Accra"}'),
  ('GN','Конакри','{"Conakry"}'),
  ('EG','Каир','{"Cairo"}'),
  ('CM','Яунде','{"Yaounde"}'),
  ('CG','Браззавиль','{"Brazzaville"}'),
  ('CD','Киншаса','{"Kinshasa"}'),
  ('CI','Ямусукро','{"Абиджан","Yamoussoukro","Abidjan"}'),
  ('LY','Триполи','{"Tripoli"}'),
  ('MU','Порт-Луи','{"Port Louis"}'),
  ('MG','Антананариву','{"Antananarivo"}'),
  ('MW','Лилонгве','{"Lilongwe"}'),
  ('ML','Бамако','{"Bamako"}'),
  ('MA','Рабат','{"Rabat"}'),
  ('NG','Абуджа','{"Abuja"}'),
  ('RW','Кигали','{"Kigali"}'),
  ('SN','Дакар','{"Dakar"}'),
  ('SD','Хартум','{"Khartoum"}'),
  ('TZ','Додома','{"Dodoma"}'),
  ('TN','Тунис','{"Tunis"}'),
  ('TD','Нджамена','{"Нъджамена","N''Djamena"}'),
  ('ET','Аддис-Абеба','{"Addis Ababa"}'),
  ('BS','Нассау','{"Nassau"}'),
  ('DO','Санто-Доминго','{"Santo Domingo"}'),
  ('CA','Оттава','{"Ottawa"}'),
  ('CR','Сан-Хосе','{"San Jose"}'),
  ('CU','Гавана','{"Havana"}'),
  ('MX','Мехико','{"Mexico City"}'),
  ('PA','Панама','{"Панама-Сити","Panama City"}'),
  ('US','Вашингтон','{"Вашингтон DC","Вашингтон округ Колумбия","Washington","Washington DC"}'),
  ('JM','Кингстон','{"Kingston"}'),
  ('AR','Буэнос-Айрес','{"Buenos Aires"}'),
  ('BO','Сукре','{"Ла-Пас","La Paz","Sucre"}'),
  ('BR','Бразилиа','{"Brasilia"}'),
  ('VE','Каракас','{"Caracas"}'),
  ('CO','Богота','{"Bogota"}'),
  ('PY','Асунсьон','{"Asuncion"}'),
  ('PE','Лима','{"Lima"}'),
  ('UY','Монтевидео','{"Montevideo"}'),
  ('CL','Сантьяго','{"Santiago"}'),
  ('EC','Кито','{"Quito"}'),
  ('AU','Канберра','{"Canberra"}'),
  ('NZ','Веллингтон','{"Wellington"}'),
  ('TW','Тайбэй','{"Тайбей","Тайпей","Taipei"}')
on conflict (iso) do update set cap = excluded.cap, alts = excluded.alts;

-- 2b. Уровни сложности стран: 1 — самые известные (режим «Легко»), 2 — средние, 3 — редкие
alter table public.cg_capitals add column if not exists tier smallint not null default 2;
update public.cg_capitals set tier = case
  when iso in ('US','CA','MX','BR','AR','CU','GB','FR','DE','IT','ES','PT','NL','BE','CH','AT','SE','NO','DK','FI','IE','PL','CZ','HU','GR','UA','TR','EG','CN','JP','KR','IN','AU','NZ','IL','TH','VN','ID','RU','IR','CL','CO','PE','VE','IS','PK','PH','NG') then 1
  when iso in ('TD','ML','GN','CM','SN','CI','GA','MG','MU','RW','BW','MW','TJ','KG','UZ','MK','BA','GE','AM','AZ','MD','LV','EE','LT','SK','SI','HR','RS','LU','MC','BS','JM','PA','CR','DO','PY','BO','EC','UY','BD','KP','TW','LA','MM','SD','LY','TN','DZ','MA','TZ','CD','CG','PS','JO','KW','AE','SY') then 3
  else 2 end;

-- 3. Комнаты матчей «Столицы»
create table if not exists public.cg_cap_matches (
  id          uuid primary key default gen_random_uuid(),
  host        uuid not null,
  guest       uuid,
  status      text not null default 'waiting',
  diff        text not null default 'normal',
  invited     boolean not null default false,
  created_at  timestamptz not null default now(),
  rh          boolean not null default false,
  rg          boolean not null default false,
  hh          integer not null default 5,
  gh          integer not null default 5,
  wh          integer not null default 0,
  wg          integer not null default 0,
  skip_h      boolean not null default false,
  skip_g      boolean not null default false,
  round       integer not null default 0,
  iso         text,
  used        text[] not null default '{}',
  round_start timestamptz,
  deadline    timestamptz,
  res         jsonb,
  hist        jsonb not null default '[]'::jsonb,
  winner      uuid,
  reason      text,
  ver         integer not null default 1
);
-- если таблица уже была — доложим недостающие колонки
alter table public.cg_cap_matches add column if not exists guest uuid;
alter table public.cg_cap_matches add column if not exists status text not null default 'waiting';
alter table public.cg_cap_matches add column if not exists diff text not null default 'normal';
alter table public.cg_cap_matches add column if not exists invited boolean not null default false;
alter table public.cg_cap_matches add column if not exists created_at timestamptz not null default now();
alter table public.cg_cap_matches add column if not exists rh boolean not null default false;
alter table public.cg_cap_matches add column if not exists rg boolean not null default false;
alter table public.cg_cap_matches add column if not exists hh integer not null default 5;
alter table public.cg_cap_matches add column if not exists gh integer not null default 5;
alter table public.cg_cap_matches add column if not exists wh integer not null default 0;
alter table public.cg_cap_matches add column if not exists wg integer not null default 0;
alter table public.cg_cap_matches add column if not exists skip_h boolean not null default false;
alter table public.cg_cap_matches add column if not exists skip_g boolean not null default false;
alter table public.cg_cap_matches add column if not exists round integer not null default 0;
alter table public.cg_cap_matches add column if not exists iso text;
alter table public.cg_cap_matches add column if not exists used text[] not null default '{}';
alter table public.cg_cap_matches add column if not exists round_start timestamptz;
alter table public.cg_cap_matches add column if not exists deadline timestamptz;
alter table public.cg_cap_matches add column if not exists res jsonb;
alter table public.cg_cap_matches add column if not exists hist jsonb not null default '[]'::jsonb;
alter table public.cg_cap_matches add column if not exists winner uuid;
alter table public.cg_cap_matches add column if not exists reason text;
alter table public.cg_cap_matches add column if not exists ver integer not null default 1;

create index if not exists cg_cap_matches_find_idx on public.cg_cap_matches (status, invited, diff, created_at);
create index if not exists cg_cap_matches_host_idx on public.cg_cap_matches (host);
create index if not exists cg_cap_matches_guest_idx on public.cg_cap_matches (guest);

-- каждое изменение комнаты увеличивает ver (клиент по нему отбрасывает старые данные)
create or replace function public.cg_cap_bump() returns trigger language plpgsql as $$
begin
  new.ver := coalesce(old.ver, 0) + 1;
  return new;
end $$;
drop trigger if exists cg_cap_bump on public.cg_cap_matches;
create trigger cg_cap_bump before update on public.cg_cap_matches
  for each row execute function public.cg_cap_bump();

-- видеть комнату могут только её участники; писать можно только через функции ниже
alter table public.cg_cap_matches enable row level security;
drop policy if exists cg_cap_sel on public.cg_cap_matches;
create policy cg_cap_sel on public.cg_cap_matches for select to authenticated
  using (host = auth.uid() or guest = auth.uid());
grant select on public.cg_cap_matches to authenticated;
alter table public.cg_cap_matches replica identity full;

-- realtime
do $do$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'cg_cap_matches') then
    alter publication supabase_realtime add table public.cg_cap_matches;
  end if;
end $do$;

-- серверное время (клиент синхронизирует по нему таймер раунда); создаём, только если нет
do $do$
begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public' and p.proname = 'cg_server_time') then
    execute 'create function public.cg_server_time() returns timestamptz language sql stable as $f$ select now() $f$';
    execute 'grant execute on function public.cg_server_time() to authenticated, anon';
  end if;
end $do$;

-- 4. Вспомогательные функции (клиенту не выдаются)
create or replace function public.cg_cap_hearts(d text) returns integer
language sql immutable as $$
  select case d when 'easy' then 10 when 'hard' then 3 else 5 end
$$;

-- убираем старую версию (1 аргумент), чтобы вызовы не конфликтовали
drop function if exists public.cg_cap_pick(text[]);

-- easy: только известные страны (tier 1); normal: все; hard: средние и редкие (tier 2–3)
create or replace function public.cg_cap_pick(u text[], d text default 'normal') returns text
language sql volatile set search_path = public as $$
  select coalesce(
    (select iso from public.cg_capitals
       where not (iso = any (coalesce(u, '{}'::text[])))
         and case d when 'easy' then tier = 1 when 'hard' then tier >= 2 else true end
       order by random() limit 1),
    (select iso from public.cg_capitals
       where case d when 'easy' then tier = 1 when 'hard' then tier >= 2 else true end
       order by random() limit 1),
    (select iso from public.cg_capitals order by random() limit 1))
$$;

-- закрыть раунд: win / skip / timeout; при skip и timeout оба теряют сердце
create or replace function public.cg_cap_resolve(p_id uuid, p_type text, p_by uuid, p_ms integer)
returns void language plpgsql security definer set search_path = public as $$
declare
  m   public.cg_cap_matches;
  cp  text;
  r   jsonb;
  nh  integer;
  ng  integer;
  nxt text;
begin
  select * into m from public.cg_cap_matches where id = p_id for update;
  if not found or m.status <> 'playing' then return; end if;
  select cap into cp from public.cg_capitals where iso = m.iso;
  r := jsonb_build_object('type', p_type, 'iso', m.iso, 'cap', cp, 'round', m.round, 'ms', p_ms);
  if p_by is not null then r := r || jsonb_build_object('by', p_by); end if;
  nh := m.hh; ng := m.gh;
  if p_type in ('skip', 'timeout') then nh := nh - 1; ng := ng - 1; end if;
  if nh <= 0 or ng <= 0 then
    update public.cg_cap_matches set
      hh = greatest(nh, 0), gh = greatest(ng, 0),
      res = r, hist = hist || jsonb_build_array(r),
      skip_h = false, skip_g = false,
      status = 'finished',
      reason = case when nh <= 0 and ng <= 0 then 'draw' else 'hearts' end,
      winner = case when nh <= 0 and ng <= 0 then null when nh <= 0 then m.guest else m.host end
    where id = p_id;
  else
    nxt := public.cg_cap_pick(m.used, m.diff);
    update public.cg_cap_matches set
      hh = nh, gh = ng,
      res = r, hist = hist || jsonb_build_array(r),
      skip_h = false, skip_g = false,
      round = m.round + 1, iso = nxt, used = array_append(m.used, nxt),
      round_start = now() + interval '4 seconds',
      deadline    = now() + interval '124 seconds'
    where id = p_id;
  end if;
end $$;

-- 5. Функции, которые вызывает игра

-- быстрый поиск соперника
create or replace function public.cg_cap_find(p_diff text default 'normal')
returns uuid language plpgsql security definer set search_path = public as $$
declare
  u uuid := auth.uid();
  d text := case when p_diff in ('easy', 'normal', 'hard') then p_diff else 'normal' end;
  v uuid;
begin
  if u is null then raise exception 'Нужно войти в аккаунт'; end if;
  -- уборка: протухшие комнаты и брошенные матчи
  update public.cg_cap_matches set status = 'cancelled', reason = 'timeout'
    where status in ('waiting', 'lobby') and created_at < now() - interval '15 minutes';
  update public.cg_cap_matches set status = 'finished', reason = 'left'
    where status = 'playing' and deadline < now() - interval '10 minutes';
  -- мои старые комнаты закрываем
  update public.cg_cap_matches set status = 'cancelled', reason = 'left'
    where status in ('waiting', 'lobby') and (host = u or guest = u);
  select id into v from public.cg_cap_matches
    where status = 'waiting' and invited = false and guest is null
      and host <> u and diff = d and created_at > now() - interval '4 minutes'
    order by created_at limit 1 for update skip locked;
  if v is not null then
    update public.cg_cap_matches set guest = u, status = 'lobby', rh = false, rg = false where id = v;
    return v;
  end if;
  insert into public.cg_cap_matches (host, diff, hh, gh) values (u, d, public.cg_cap_hearts(d), public.cg_cap_hearts(d))
    returning id into v;
  return v;
end $$;

-- приглашение друга
create or replace function public.cg_cap_invite(p_friend uuid, p_diff text default 'normal')
returns uuid language plpgsql security definer set search_path = public as $$
declare
  u uuid := auth.uid();
  d text := case when p_diff in ('easy', 'normal', 'hard') then p_diff else 'normal' end;
  v uuid;
begin
  if u is null then raise exception 'Нужно войти в аккаунт'; end if;
  if p_friend is null or p_friend = u then raise exception 'Нельзя пригласить себя'; end if;
  if not exists (select 1 from public.cg_friendships f
                 where f.status = 'accepted'
                   and ((f.requester = u and f.addressee = p_friend) or (f.requester = p_friend and f.addressee = u))) then
    raise exception 'Этот игрок не в вашем списке друзей';
  end if;
  update public.cg_cap_matches set status = 'cancelled', reason = 'left'
    where status in ('waiting', 'lobby') and (host = u or guest = u);
  insert into public.cg_cap_matches (host, guest, diff, invited, hh, gh)
    values (u, p_friend, d, true, public.cg_cap_hearts(d), public.cg_cap_hearts(d))
    returning id into v;
  return v;
end $$;

-- гость принимает приглашение
create or replace function public.cg_cap_accept(p_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Нужно войти в аккаунт'; end if;
  update public.cg_cap_matches set status = 'lobby', rh = false, rg = false
    where id = p_id and guest = u and status = 'waiting' and invited = true
      and created_at > now() - interval '15 minutes';
  return found;
end $$;

-- гость отклоняет приглашение
create or replace function public.cg_cap_decline(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Нужно войти в аккаунт'; end if;
  update public.cg_cap_matches set status = 'declined'
    where id = p_id and guest = u and status = 'waiting';
end $$;

-- хозяин выбирает сложность (готовность сбрасывается)
create or replace function public.cg_cap_set(p_id uuid, p_diff text) returns void
language plpgsql security definer set search_path = public as $$
declare u uuid := auth.uid(); d text;
begin
  if u is null then raise exception 'Нужно войти в аккаунт'; end if;
  d := case when p_diff in ('easy', 'normal', 'hard') then p_diff else 'normal' end;
  update public.cg_cap_matches
    set diff = d, hh = public.cg_cap_hearts(d), gh = public.cg_cap_hearts(d), rh = false, rg = false
    where id = p_id and host = u and status in ('waiting', 'lobby');
end $$;

-- «Готов»; когда готовы оба — матч стартует
create or replace function public.cg_cap_ready(p_id uuid, p_ready boolean) returns text
language plpgsql security definer set search_path = public as $$
declare
  u uuid := auth.uid();
  m public.cg_cap_matches;
  is_host boolean;
  rh2 boolean;
  rg2 boolean;
  first_iso text;
begin
  if u is null then raise exception 'Нужно войти в аккаунт'; end if;
  select * into m from public.cg_cap_matches where id = p_id for update;
  if not found or (m.host <> u and m.guest is distinct from u) then raise exception 'Матч не найден'; end if;
  if m.status = 'waiting' then raise exception 'Соперник ещё не в комнате'; end if;
  if m.status <> 'lobby' then raise exception 'Комната закрыта'; end if;
  is_host := (m.host = u);
  rh2 := case when is_host then coalesce(p_ready, false) else m.rh end;
  rg2 := case when is_host then m.rg else coalesce(p_ready, false) end;
  if rh2 and rg2 then
    first_iso := public.cg_cap_pick('{}'::text[], m.diff);
    update public.cg_cap_matches set
      rh = true, rg = true, status = 'playing',
      hh = public.cg_cap_hearts(m.diff), gh = public.cg_cap_hearts(m.diff), wh = 0, wg = 0,
      skip_h = false, skip_g = false, round = 1, iso = first_iso, used = array[first_iso],
      round_start = now() + interval '4 seconds', deadline = now() + interval '124 seconds',
      res = null, hist = '[]'::jsonb, winner = null, reason = null
    where id = p_id;
    return 'started';
  end if;
  update public.cg_cap_matches set rh = rh2, rg = rg2 where id = p_id;
  return 'ok';
end $$;

-- ответ игрока: 'correct' | 'wrong' | 'early' | 'late' | 'stale' | 'closed'
create or replace function public.cg_cap_answer(p_id uuid, p_round integer, p_text text) returns text
language plpgsql security definer set search_path = public as $$
declare
  u uuid := auth.uid();
  m public.cg_cap_matches;
  k text;
  ok boolean;
  ms integer;
  mine boolean;
begin
  if u is null then raise exception 'Нужно войти в аккаунт'; end if;
  select * into m from public.cg_cap_matches where id = p_id for update;
  if not found or (m.host <> u and m.guest is distinct from u) then raise exception 'Матч не найден'; end if;
  if m.status <> 'playing' then return 'closed'; end if;
  if p_round is distinct from m.round then return 'stale'; end if;
  if now() < m.round_start then return 'early'; end if;
  if now() >= m.deadline then return 'late'; end if;
  k := public.cg_norm(p_text);
  select (k <> '' and (public.cg_norm(c.cap) = k
                       or exists (select 1 from unnest(c.alts) a where public.cg_norm(a) = k)))
    into ok from public.cg_capitals c where c.iso = m.iso;
  if coalesce(ok, false) then
    ms := greatest(0, (extract(epoch from (now() - m.round_start)) * 1000)::integer);
    perform public.cg_cap_resolve(p_id, 'win', u, ms);
    return 'correct';
  end if;
  mine := (m.host = u);
  update public.cg_cap_matches set
    hh = case when mine then greatest(hh - 1, 0) else hh end,
    gh = case when mine then gh else greatest(gh - 1, 0) end,
    wh = wh + case when mine then 1 else 0 end,
    wg = wg + case when mine then 0 else 1 end,
    status = case when (case when mine then hh else gh end) - 1 <= 0 then 'finished' else status end,
    reason = case when (case when mine then hh else gh end) - 1 <= 0 then 'hearts' else reason end,
    winner = case when (case when mine then hh else gh end) - 1 <= 0
                  then (case when mine then guest else host end) else winner end
  where id = p_id;
  return 'wrong';
end $$;

-- «Не знаю ответ»: пропуск, когда нажали оба
create or replace function public.cg_cap_skip(p_id uuid, p_round integer) returns text
language plpgsql security definer set search_path = public as $$
declare
  u uuid := auth.uid();
  m public.cg_cap_matches;
  sh boolean;
  sg boolean;
begin
  if u is null then raise exception 'Нужно войти в аккаунт'; end if;
  select * into m from public.cg_cap_matches where id = p_id for update;
  if not found or (m.host <> u and m.guest is distinct from u) then raise exception 'Матч не найден'; end if;
  if m.status <> 'playing' then return 'closed'; end if;
  if p_round is distinct from m.round then return 'stale'; end if;
  if now() < m.round_start then return 'early'; end if;
  sh := m.skip_h or (m.host = u);
  sg := m.skip_g or (m.guest is not distinct from u);
  if sh and sg then
    perform public.cg_cap_resolve(p_id, 'skip', null, 0);
    return 'skip';
  end if;
  update public.cg_cap_matches set skip_h = sh, skip_g = sg where id = p_id;
  return 'wait';
end $$;

-- время раунда вышло (может вызвать любой из игроков): оба теряют сердце
create or replace function public.cg_cap_tick(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare
  u uuid := auth.uid();
  m public.cg_cap_matches;
begin
  if u is null then raise exception 'Нужно войти в аккаунт'; end if;
  select * into m from public.cg_cap_matches where id = p_id for update;
  if not found or (m.host <> u and m.guest is distinct from u) then raise exception 'Матч не найден'; end if;
  if m.status <> 'playing' then return 'closed'; end if;
  if now() < m.deadline then return 'early'; end if;
  perform public.cg_cap_resolve(p_id, 'timeout', null, 120000);
  return 'timeout';
end $$;

-- выход: в комнате — закрывает её, в матче — засчитывает поражение
create or replace function public.cg_cap_resign(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  u uuid := auth.uid();
  m public.cg_cap_matches;
begin
  if u is null then raise exception 'Нужно войти в аккаунт'; end if;
  select * into m from public.cg_cap_matches where id = p_id for update;
  if not found or (m.host <> u and m.guest is distinct from u) then return; end if;
  if m.status in ('waiting', 'lobby') then
    update public.cg_cap_matches set status = 'cancelled', reason = 'left' where id = p_id;
  elsif m.status = 'playing' then
    update public.cg_cap_matches set status = 'finished', reason = 'left',
      winner = case when m.host = u then m.guest else m.host end
    where id = p_id;
  end if;
end $$;

-- 6. Права: игра вызывает только функции из этого списка
revoke all on function public.cg_cap_find(text) from public, anon;
revoke all on function public.cg_cap_invite(uuid, text) from public, anon;
revoke all on function public.cg_cap_accept(uuid) from public, anon;
revoke all on function public.cg_cap_decline(uuid) from public, anon;
revoke all on function public.cg_cap_set(uuid, text) from public, anon;
revoke all on function public.cg_cap_ready(uuid, boolean) from public, anon;
revoke all on function public.cg_cap_answer(uuid, integer, text) from public, anon;
revoke all on function public.cg_cap_skip(uuid, integer) from public, anon;
revoke all on function public.cg_cap_tick(uuid) from public, anon;
revoke all on function public.cg_cap_resign(uuid) from public, anon;
revoke all on function public.cg_cap_resolve(uuid, text, uuid, integer) from public, anon, authenticated;
grant execute on function public.cg_cap_find(text) to authenticated;
grant execute on function public.cg_cap_invite(uuid, text) to authenticated;
grant execute on function public.cg_cap_accept(uuid) to authenticated;
grant execute on function public.cg_cap_decline(uuid) to authenticated;
grant execute on function public.cg_cap_set(uuid, text) to authenticated;
grant execute on function public.cg_cap_ready(uuid, boolean) to authenticated;
grant execute on function public.cg_cap_answer(uuid, integer, text) to authenticated;
grant execute on function public.cg_cap_skip(uuid, integer) to authenticated;
grant execute on function public.cg_cap_tick(uuid) to authenticated;
grant execute on function public.cg_cap_resign(uuid) to authenticated;

-- 7. Обновить кэш схемы API, чтобы функции были видны сразу
notify pgrst, 'reload schema';

-- 8. Итоговая проверка: везде должно быть OK
select item as "Что проверяем", case when ok then 'OK' else 'НЕТ — запустите скрипт ещё раз' end as "Результат"
from (values
  ('колонка cg_profiles.prem', exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'cg_profiles' and column_name = 'prem')),
  ('таблица cg_cap_matches', to_regclass('public.cg_cap_matches') is not null),
  ('столицы загружены (больше 100)', (select count(*) from public.cg_capitals) > 100),
  ('столицы с уровнями сложности', exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'cg_capitals' and column_name = 'tier')),
  ('функция cg_cap_pick', to_regprocedure('public.cg_cap_pick(text[],text)') is not null),
  ('функция cg_cap_find', to_regprocedure('public.cg_cap_find(text)') is not null),
  ('функция cg_cap_invite', to_regprocedure('public.cg_cap_invite(uuid,text)') is not null),
  ('функция cg_cap_accept', to_regprocedure('public.cg_cap_accept(uuid)') is not null),
  ('функция cg_cap_set', to_regprocedure('public.cg_cap_set(uuid,text)') is not null),
  ('функция cg_cap_ready', to_regprocedure('public.cg_cap_ready(uuid,boolean)') is not null),
  ('функция cg_cap_answer', to_regprocedure('public.cg_cap_answer(uuid,integer,text)') is not null),
  ('функция cg_cap_skip', to_regprocedure('public.cg_cap_skip(uuid,integer)') is not null),
  ('функция cg_cap_tick', to_regprocedure('public.cg_cap_tick(uuid)') is not null),
  ('функция cg_cap_resign', to_regprocedure('public.cg_cap_resign(uuid)') is not null),
  ('realtime: cg_cap_matches', exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'cg_cap_matches'))
) as v(item, ok);
