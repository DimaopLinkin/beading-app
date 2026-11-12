-- ADR-0006: синхронизация «Канители» между устройствами одного пользователя.
-- Одна таблица записей, правила доступа «каждый видит только свои строки», LWW в триггере,
-- закрытое хранилище файлов и пустая функция для ежедневного пинга от паузы проекта.

-- ---------------------------------------------------------------- записи
create sequence if not exists public.sync_seq;

create table public.sync_records (
  user_id    uuid   not null default auth.uid() references auth.users on delete cascade,
  entity     text   not null,
  sync_id    text   not null,
  updated_at bigint not null,            -- UTC, миллисекунды
  deleted_at bigint,                     -- надгробие, хранится бессрочно
  device_id  text   not null,
  data       jsonb  not null default '{}'::jsonb,
  server_seq bigint not null default 0,  -- курсор для pull, выдаёт триггер
  primary key (user_id, entity, sync_id)
);

create index sync_records_user_seq_idx on public.sync_records (user_id, server_seq);

-- ---------------------------------------------------------------- триггер LWW
-- Старая запись не затирает новую при любом пути записи (обычный upsert PostgREST).
-- Advisory lock на пользователя сериализует записи, поэтому server_seq выдаются
-- и фиксируются в одном порядке и курсор читателя не пропускает записи (R-02).
create or replace function public.sync_records_before_write()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
begin
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));
  new.user_id := auth.uid();
  new.updated_at := least(new.updated_at, now_ms + 300000);  -- часы вперёд не дальше 5 минут
  if tg_op = 'UPDATE' then
    if (new.updated_at, new.device_id) <= (old.updated_at, old.device_id) then
      return null;                                            -- устаревшая запись пропускается молча
    end if;
  end if;
  new.server_seq := nextval('public.sync_seq');
  return new;
end;
$$;

create trigger sync_records_before_write
  before insert or update on public.sync_records
  for each row execute function public.sync_records_before_write();

-- ---------------------------------------------------------------- права и RLS
alter table public.sync_records enable row level security;

revoke all on public.sync_records from anon;
revoke all on public.sync_records from authenticated;
grant select, insert, update on public.sync_records to authenticated;
grant usage on sequence public.sync_seq to authenticated;

create policy sync_records_select on public.sync_records
  for select to authenticated using (user_id = (select auth.uid()));
create policy sync_records_insert on public.sync_records
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy sync_records_update on public.sync_records
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------- realtime
-- Событие только будит pull; содержимое клиент из события не применяет.
alter publication supabase_realtime add table public.sync_records;

-- ---------------------------------------------------------------- хранилище файлов
-- Приватный бакет; путь {user_id}/..., объекты неизменяемые (без update).
insert into storage.buckets (id, name, public)
values ('blobs', 'blobs', false)
on conflict (id) do nothing;

create policy blobs_select on storage.objects
  for select to authenticated
  using (bucket_id = 'blobs' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy blobs_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'blobs' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy blobs_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'blobs' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ---------------------------------------------------------------- пинг от паузы
-- Ничего не читает и не пишет; вызывается ежедневно из GitHub Actions с публичным ключом.
create or replace function public.keep_alive()
returns integer
language sql
stable
security invoker
set search_path = ''
as $$ select 1 $$;

revoke all on function public.keep_alive() from public;
grant execute on function public.keep_alive() to anon, authenticated;
