-- Executar como administrador apos revisar o DDL e as associacoes divergentes.
-- PostgreSQL 15+. Transacional e reexecutavel; nao apaga doses.
-- Diagnostico previo (revisar antes de executar o restante):
-- select d.id, d.alarme_id, d.usuario_id, a.usuario_id as dono_alarme
-- from app.registro_doses d left join app.alarmes a on a.id = d.alarme_id
-- where d.alarme_id is not null and a.usuario_id is distinct from d.usuario_id;
begin;
set local lock_timeout = '5s';

do $$ begin
  if current_setting('server_version_num')::integer < 150000 then
    raise exception 'SEC-03 exige PostgreSQL 15 ou superior.';
  end if;
end $$;

-- Evita gravacoes concorrentes durante a correcao e validacao do historico.
lock table app.alarmes, app.registro_doses in access exclusive mode;

do $$ begin
  if not exists (select 1 from pg_constraint
    where conrelid = 'app.alarmes'::regclass and conname = 'alarmes_id_usuario_unico') then
    alter table app.alarmes add constraint alarmes_id_usuario_unico unique (id, usuario_id);
  end if;
  if not exists (select 1 from pg_constraint
    where conrelid = 'app.registro_doses'::regclass and conname = 'doses_alarme_mesmo_dono') then
    alter table app.registro_doses add constraint doses_alarme_mesmo_dono
      foreign key (alarme_id, usuario_id) references app.alarmes (id, usuario_id)
      on delete set null (alarme_id) not valid;
  end if;
end $$;

update app.registro_doses d set alarme_id = null
where d.alarme_id is not null and not exists (
  select 1 from app.alarmes a where a.id = d.alarme_id and a.usuario_id = d.usuario_id
);

alter table app.registro_doses validate constraint doses_alarme_mesmo_dono;

-- Descobre o nome real de todas as FKs simples legadas para app.alarmes(id).
do $$ declare legado record; begin
  for legado in
    select c.conname from pg_constraint c
    where c.contype = 'f' and c.conrelid = 'app.registro_doses'::regclass
      and c.confrelid = 'app.alarmes'::regclass
      and c.conkey = array[(select attnum from pg_attribute
        where attrelid = c.conrelid and attname = 'alarme_id')]::smallint[]
      and c.confkey = array[(select attnum from pg_attribute
        where attrelid = c.confrelid and attname = 'id')]::smallint[]
  loop
    execute format('alter table app.registro_doses drop constraint %I', legado.conname);
  end loop;
end $$;

create index if not exists registro_doses_alarme_usuario_idx
  on app.registro_doses (alarme_id, usuario_id);
commit;
