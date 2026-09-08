-- ============================================================================
-- LembreBem - Novas tabelas para as telas do prototipo
-- Rodar no Supabase: SQL Editor > New query > colar tudo > Run
-- Seguro re-executar (IF NOT EXISTS / OR REPLACE em tudo).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) PERFIL ESTENDIDO EM app.usuarios
--    Campos novos usados na tela de Perfil do prototipo.
-- ----------------------------------------------------------------------------
alter table app.usuarios add column if not exists telefone        text;
alter table app.usuarios add column if not exists cep             text;
alter table app.usuarios add column if not exists logradouro      text;
alter table app.usuarios add column if not exists numero          text;
alter table app.usuarios add column if not exists bairro          text;
alter table app.usuarios add column if not exists cidade          text;
alter table app.usuarios add column if not exists estado          text;
alter table app.usuarios add column if not exists tipo_sanguineo  text;
alter table app.usuarios add column if not exists cartao_sus      text;
alter table app.usuarios add column if not exists convenio        text;
alter table app.usuarios add column if not exists alergias        text;
alter table app.usuarios add column if not exists foto_data_url   text;
alter table app.usuarios add column if not exists codigo_vinculacao text;

-- Gera codigo de vinculacao de 6 digitos (usado pelo cuidador para vincular)
create or replace function app.gerar_codigo_vinculacao()
returns text
language sql
volatile
as $$
  select lpad((floor(random() * 1000000))::int::text, 6, '0');
$$;

-- Preenche codigo para usuarios existentes que ainda nao tem
update app.usuarios
   set codigo_vinculacao = app.gerar_codigo_vinculacao()
 where codigo_vinculacao is null;

-- Trigger: novo usuario ja nasce com codigo
create or replace function app.trg_usuarios_codigo_vinculacao()
returns trigger
language plpgsql
as $$
begin
  if new.codigo_vinculacao is null then
    new.codigo_vinculacao := app.gerar_codigo_vinculacao();
  end if;
  return new;
end;
$$;

drop trigger if exists usuarios_codigo_vinculacao on app.usuarios;
create trigger usuarios_codigo_vinculacao
  before insert on app.usuarios
  for each row execute function app.trg_usuarios_codigo_vinculacao();

-- ----------------------------------------------------------------------------
-- 2) CUIDADORES
-- ----------------------------------------------------------------------------
create table if not exists app.cuidadores (
  id                     uuid primary key references auth.users (id) on delete cascade,
  nome                   text not null,
  email                  text not null,
  registro_profissional  text,          -- COREN / CRM (opcional)
  criado_em              timestamptz not null default now()
);

alter table app.cuidadores enable row level security;
grant select, insert, update, delete on app.cuidadores to authenticated;

drop policy if exists cuidadores_proprio on app.cuidadores;
create policy cuidadores_proprio on app.cuidadores
  for all to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ----------------------------------------------------------------------------
-- 3) VINCULO CUIDADOR <-> PACIENTE
-- ----------------------------------------------------------------------------
create table if not exists app.cuidador_pacientes (
  id            uuid primary key default gen_random_uuid(),
  cuidador_id   uuid not null references app.cuidadores (id) on delete cascade,
  paciente_id   uuid not null references app.usuarios (id) on delete cascade,
  vinculado_em  timestamptz not null default now(),
  unique (cuidador_id, paciente_id)
);

alter table app.cuidador_pacientes enable row level security;
grant select, insert, delete on app.cuidador_pacientes to authenticated;

drop policy if exists cuidador_pacientes_do_cuidador on app.cuidador_pacientes;
create policy cuidador_pacientes_do_cuidador on app.cuidador_pacientes
  for select to authenticated
  using (cuidador_id = auth.uid() or paciente_id = auth.uid());

drop policy if exists cuidador_pacientes_delete on app.cuidador_pacientes;
create policy cuidador_pacientes_delete on app.cuidador_pacientes
  for delete to authenticated
  using (cuidador_id = auth.uid() or paciente_id = auth.uid());

-- RPC: cuidador vincula paciente informando o codigo de 6 digitos
-- (SECURITY DEFINER porque o cuidador nao enxerga app.usuarios de outros)
create or replace function app.vincular_paciente(codigo text)
returns uuid
language plpgsql
security definer
set search_path = app, public
as $$
declare
  v_paciente_id uuid;
  v_vinculo_id  uuid;
begin
  if not exists (select 1 from app.cuidadores where id = auth.uid()) then
    raise exception 'Apenas cuidadores podem vincular pacientes.';
  end if;

  select id into v_paciente_id
    from app.usuarios
   where codigo_vinculacao = codigo
   limit 1;

  if v_paciente_id is null then
    raise exception 'Codigo de vinculacao invalido.';
  end if;

  insert into app.cuidador_pacientes (cuidador_id, paciente_id)
  values (auth.uid(), v_paciente_id)
  on conflict (cuidador_id, paciente_id) do update set vinculado_em = now()
  returning id into v_vinculo_id;

  return v_vinculo_id;
end;
$$;

grant execute on function app.vincular_paciente(text) to authenticated;

-- Cuidador pode LER dados dos pacientes vinculados
drop policy if exists usuarios_leitura_cuidador on app.usuarios;
create policy usuarios_leitura_cuidador on app.usuarios
  for select to authenticated
  using (
    exists (
      select 1 from app.cuidador_pacientes cp
       where cp.paciente_id = usuarios.id
         and cp.cuidador_id = auth.uid()
    )
  );

drop policy if exists alarmes_leitura_cuidador on app.alarmes;
create policy alarmes_leitura_cuidador on app.alarmes
  for select to authenticated
  using (
    exists (
      select 1 from app.cuidador_pacientes cp
       where cp.paciente_id = alarmes.usuario_id
         and cp.cuidador_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- 4) FAVORITOS (coracao na busca / aba "Em Uso")
-- ----------------------------------------------------------------------------
create table if not exists app.favoritos (
  id              uuid primary key default gen_random_uuid(),
  usuario_id      uuid not null references app.usuarios (id) on delete cascade,
  medicamento_id  bigint not null,
  criado_em       timestamptz not null default now(),
  unique (usuario_id, medicamento_id)
);

alter table app.favoritos enable row level security;
grant select, insert, delete on app.favoritos to authenticated;

drop policy if exists favoritos_proprio on app.favoritos;
create policy favoritos_proprio on app.favoritos
  for all to authenticated
  using (usuario_id = auth.uid())
  with check (usuario_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 5) RECEITAS (PDF anexado na aba "Receitas")
-- ----------------------------------------------------------------------------
create table if not exists app.receitas (
  id              uuid primary key default gen_random_uuid(),
  usuario_id      uuid not null references app.usuarios (id) on delete cascade,
  nome            text not null,
  nome_arquivo    text not null,
  arquivo_base64  text,               -- conteudo do PDF em base64
  criado_em       timestamptz not null default now()
);

alter table app.receitas enable row level security;
grant select, insert, delete on app.receitas to authenticated;

drop policy if exists receitas_proprio on app.receitas;
create policy receitas_proprio on app.receitas
  for all to authenticated
  using (usuario_id = auth.uid())
  with check (usuario_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 6) CONTATOS DE EMERGENCIA (contatos de confianca)
-- ----------------------------------------------------------------------------
create table if not exists app.contatos_emergencia (
  id          uuid primary key default gen_random_uuid(),
  usuario_id  uuid not null references app.usuarios (id) on delete cascade,
  nome        text not null,
  telefone    text not null,
  criado_em   timestamptz not null default now()
);

alter table app.contatos_emergencia enable row level security;
grant select, insert, update, delete on app.contatos_emergencia to authenticated;

drop policy if exists contatos_emergencia_proprio on app.contatos_emergencia;
create policy contatos_emergencia_proprio on app.contatos_emergencia
  for all to authenticated
  using (usuario_id = auth.uid())
  with check (usuario_id = auth.uid());

-- Cuidador le contatos de emergencia dos pacientes vinculados (ficha)
drop policy if exists contatos_emergencia_cuidador on app.contatos_emergencia;
create policy contatos_emergencia_cuidador on app.contatos_emergencia
  for select to authenticated
  using (
    exists (
      select 1 from app.cuidador_pacientes cp
       where cp.paciente_id = contatos_emergencia.usuario_id
         and cp.cuidador_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- 7) REGISTRO DE DOSES (linha do tempo + relatorios do cuidador)
-- ----------------------------------------------------------------------------
create table if not exists app.registro_doses (
  id                uuid primary key default gen_random_uuid(),
  usuario_id        uuid not null references app.usuarios (id) on delete cascade,
  alarme_id         uuid references app.alarmes (id) on delete set null,
  medicamento_nome  text not null,
  dose              text,
  horario_previsto  timestamptz not null,
  status            text not null default 'pendente'
                    check (status in ('tomada', 'atrasada', 'perdida', 'pendente')),
  registrado_em     timestamptz
);

alter table app.registro_doses enable row level security;
grant select, insert, update, delete on app.registro_doses to authenticated;

drop policy if exists registro_doses_proprio on app.registro_doses;
create policy registro_doses_proprio on app.registro_doses
  for all to authenticated
  using (usuario_id = auth.uid())
  with check (usuario_id = auth.uid());

drop policy if exists registro_doses_cuidador on app.registro_doses;
create policy registro_doses_cuidador on app.registro_doses
  for select to authenticated
  using (
    exists (
      select 1 from app.cuidador_pacientes cp
       where cp.paciente_id = registro_doses.usuario_id
         and cp.cuidador_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- 8) SEEDS DE EXEMPLO (dados p/ dashboard do cuidador ja mostrar algo)
--    Usa a conta de teste teste1@gmail.com como paciente.
-- ----------------------------------------------------------------------------
do $$
declare
  v_paciente uuid;
begin
  select id into v_paciente from app.usuarios where email = 'teste1@gmail.com' limit 1;

  if v_paciente is not null then
    -- doses de hoje
    insert into app.registro_doses (usuario_id, medicamento_nome, dose, horario_previsto, status, registrado_em)
    select v_paciente, m.nome, m.dose, date_trunc('day', now()) + m.hora, m.status, m.reg
      from (values
        ('Paracetamol', '500mg', interval '8 hours',  'tomada',   now()),
        ('Ibuprofeno',  '400mg', interval '14 hours', 'perdida',  null::timestamptz),
        ('Buspirona',   '10mg',  interval '20 hours', 'pendente', null::timestamptz)
      ) as m(nome, dose, hora, status, reg)
     where not exists (
       select 1 from app.registro_doses rd
        where rd.usuario_id = v_paciente
          and rd.horario_previsto::date = current_date
     );

    -- historico dos ultimos 7 dias (p/ grafico de adesao semanal)
    insert into app.registro_doses (usuario_id, medicamento_nome, dose, horario_previsto, status, registrado_em)
    select v_paciente,
           'Paracetamol', '500mg',
           date_trunc('day', now()) - (d.dia || ' days')::interval + interval '8 hours',
           case when d.dia % 3 = 0 then 'atrasada' else 'tomada' end,
           date_trunc('day', now()) - (d.dia || ' days')::interval + interval '8 hours'
      from generate_series(1, 7) as d(dia)
     where not exists (
       select 1 from app.registro_doses rd
        where rd.usuario_id = v_paciente
          and rd.horario_previsto < current_date
     );
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 9) CONSULTAS DE VERIFICACAO (rodar depois, uma a uma, se quiser conferir)
-- ----------------------------------------------------------------------------
-- Codigo de vinculacao do paciente de teste:
-- select email, codigo_vinculacao from app.usuarios where email = 'teste1@gmail.com';

-- Doses registradas do paciente de teste:
-- select medicamento_nome, dose, horario_previsto, status
--   from app.registro_doses rd
--   join app.usuarios u on u.id = rd.usuario_id
--  where u.email = 'teste1@gmail.com'
--  order by horario_previsto;

-- Cuidadores cadastrados e seus pacientes:
-- select c.nome as cuidador, u.nome as paciente, cp.vinculado_em
--   from app.cuidador_pacientes cp
--   join app.cuidadores c on c.id = cp.cuidador_id
--   join app.usuarios  u on u.id = cp.paciente_id;
