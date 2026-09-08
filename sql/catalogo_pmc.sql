create schema if not exists catalogo;

create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;

create or replace function catalogo.atualizar_coluna_atualizado_em()
returns trigger
language plpgsql
as $$
begin
  new.atualizado_em = timezone('utc', now());
  return new;
end;
$$;

create table if not exists catalogo.fabricantes (
  id bigserial primary key,
  chave_importacao text not null unique,
  cnpj varchar(18),
  nome text not null,
  nome_normalizado text not null,
  lote_importacao text not null default '',
  criado_em timestamptz not null default timezone('utc', now()),
  atualizado_em timestamptz not null default timezone('utc', now())
);

create table if not exists catalogo.principios_ativos (
  id bigserial primary key,
  nome text not null,
  nome_normalizado text not null unique,
  lote_importacao text not null default '',
  criado_em timestamptz not null default timezone('utc', now()),
  atualizado_em timestamptz not null default timezone('utc', now())
);

create table if not exists catalogo.medicamentos_base (
  id bigserial primary key,
  registro varchar(20) not null unique,
  nome_produto text not null,
  nome_produto_normalizado text not null,
  substancia text,
  substancia_normalizada text,
  classe_terapeutica text,
  tipo_produto text,
  tipo_medicamento text,
  regime_preco text,
  fabricante_id bigint not null references catalogo.fabricantes(id),
  lote_importacao text not null default '',
  dados_origem jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default timezone('utc', now()),
  atualizado_em timestamptz not null default timezone('utc', now())
);

create table if not exists catalogo.medicamentos_principios_ativos (
  medicamento_id bigint not null references catalogo.medicamentos_base(id) on delete cascade,
  principio_ativo_id bigint not null references catalogo.principios_ativos(id) on delete cascade,
  ordem smallint not null default 1,
  principal boolean not null default false,
  criado_em timestamptz not null default timezone('utc', now()),
  primary key (medicamento_id, principio_ativo_id)
);

create table if not exists catalogo.apresentacoes (
  id bigserial primary key,
  medicamento_id bigint not null references catalogo.medicamentos_base(id) on delete cascade,
  codigo_ggrem varchar(30) not null unique,
  apresentacao text not null,
  apresentacao_normalizada text not null,
  concentracao_dosagem text,
  unidade text,
  ean_1 varchar(20),
  ean_2 varchar(20),
  ean_3 varchar(20),
  ean_principal varchar(20),
  pf_preco_padrao numeric(14, 2),
  pmc_preco_padrao numeric(14, 2),
  aliquota_pf_padrao text,
  aliquota_pmc_padrao text,
  precos_pf jsonb not null default '{}'::jsonb,
  precos_pmc jsonb not null default '{}'::jsonb,
  restricao_hospitalar boolean,
  cap boolean,
  confaz_87 boolean,
  icms_0 boolean,
  analise_recursal text,
  credito_tributario_piscofins text,
  comercializacao_2024 boolean,
  tarja text,
  destinacao_comercial text,
  lote_importacao text not null default '',
  dados_origem jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default timezone('utc', now()),
  atualizado_em timestamptz not null default timezone('utc', now())
);

drop trigger if exists trg_fabricantes_atualizado_em on catalogo.fabricantes;
create trigger trg_fabricantes_atualizado_em
before update on catalogo.fabricantes
for each row
execute function catalogo.atualizar_coluna_atualizado_em();

drop trigger if exists trg_principios_ativos_atualizado_em on catalogo.principios_ativos;
create trigger trg_principios_ativos_atualizado_em
before update on catalogo.principios_ativos
for each row
execute function catalogo.atualizar_coluna_atualizado_em();

drop trigger if exists trg_medicamentos_base_atualizado_em on catalogo.medicamentos_base;
create trigger trg_medicamentos_base_atualizado_em
before update on catalogo.medicamentos_base
for each row
execute function catalogo.atualizar_coluna_atualizado_em();

drop trigger if exists trg_apresentacoes_atualizado_em on catalogo.apresentacoes;
create trigger trg_apresentacoes_atualizado_em
before update on catalogo.apresentacoes
for each row
execute function catalogo.atualizar_coluna_atualizado_em();

create index if not exists idx_fabricantes_nome_trgm
  on catalogo.fabricantes using gin (nome_normalizado gin_trgm_ops);

create index if not exists idx_medicamentos_base_nome_trgm
  on catalogo.medicamentos_base using gin (nome_produto_normalizado gin_trgm_ops);

create index if not exists idx_medicamentos_base_substancia_trgm
  on catalogo.medicamentos_base using gin (substancia_normalizada gin_trgm_ops);

create index if not exists idx_medicamentos_base_fabricante
  on catalogo.medicamentos_base (fabricante_id);

create index if not exists idx_apresentacoes_medicamento
  on catalogo.apresentacoes (medicamento_id);

create index if not exists idx_apresentacoes_ggrem
  on catalogo.apresentacoes (codigo_ggrem);

create index if not exists idx_apresentacoes_ean_principal
  on catalogo.apresentacoes (ean_principal);

create index if not exists idx_apresentacoes_apresentacao_trgm
  on catalogo.apresentacoes using gin (apresentacao_normalizada gin_trgm_ops);

create index if not exists idx_principios_ativos_nome_trgm
  on catalogo.principios_ativos using gin (nome_normalizado gin_trgm_ops);

create or replace view catalogo.medicamentos as
with principios_agregados as (
  select
    rel.medicamento_id,
    array_agg(pa.nome order by rel.ordem asc, pa.nome asc) as principios_ativos,
    string_agg(pa.nome, '; ' order by rel.ordem asc, pa.nome asc) as principio_ativo_texto
  from catalogo.medicamentos_principios_ativos rel
  join catalogo.principios_ativos pa
    on pa.id = rel.principio_ativo_id
  group by rel.medicamento_id
)
select
  a.id,
  m.id as medicamento_id,
  a.codigo_ggrem,
  m.registro,
  m.nome_produto,
  m.nome_produto_normalizado,
  coalesce(p.principio_ativo_texto, m.substancia) as principio_ativo,
  m.substancia_normalizada as principio_ativo_normalizado,
  coalesce(
    p.principios_ativos,
    case
      when m.substancia is null or btrim(m.substancia) = '' then array[]::text[]
      else string_to_array(m.substancia, ';')
    end
  ) as principios_ativos,
  f.nome as fabricante,
  f.nome as empresa_detentora_registro,
  f.nome_normalizado as fabricante_normalizado,
  f.cnpj as cnpj_fabricante,
  a.apresentacao,
  a.apresentacao_normalizada,
  a.concentracao_dosagem,
  a.unidade,
  m.classe_terapeutica,
  m.tipo_produto,
  m.tipo_medicamento,
  m.regime_preco,
  a.ean_principal as ean,
  a.ean_1,
  a.ean_2,
  a.ean_3,
  a.pf_preco_padrao as pf,
  a.pmc_preco_padrao as pmc,
  coalesce(a.pmc_preco_padrao, a.pf_preco_padrao) as preco,
  a.aliquota_pf_padrao,
  a.aliquota_pmc_padrao,
  a.restricao_hospitalar,
  a.cap,
  a.confaz_87,
  a.icms_0,
  a.analise_recursal,
  a.credito_tributario_piscofins,
  a.comercializacao_2024,
  a.tarja,
  a.destinacao_comercial
from catalogo.apresentacoes a
join catalogo.medicamentos_base m
  on m.id = a.medicamento_id
join catalogo.fabricantes f
  on f.id = m.fabricante_id
left join principios_agregados p
  on p.medicamento_id = m.id;

alter table catalogo.fabricantes enable row level security;
alter table catalogo.principios_ativos enable row level security;
alter table catalogo.medicamentos_base enable row level security;
alter table catalogo.medicamentos_principios_ativos enable row level security;
alter table catalogo.apresentacoes enable row level security;

drop policy if exists fabricantes_leitura_publica on catalogo.fabricantes;
create policy fabricantes_leitura_publica
on catalogo.fabricantes
for select
to anon, authenticated
using (true);

drop policy if exists principios_ativos_leitura_publica on catalogo.principios_ativos;
create policy principios_ativos_leitura_publica
on catalogo.principios_ativos
for select
to anon, authenticated
using (true);

drop policy if exists medicamentos_base_leitura_publica on catalogo.medicamentos_base;
create policy medicamentos_base_leitura_publica
on catalogo.medicamentos_base
for select
to anon, authenticated
using (true);

drop policy if exists medicamentos_principios_ativos_leitura_publica on catalogo.medicamentos_principios_ativos;
create policy medicamentos_principios_ativos_leitura_publica
on catalogo.medicamentos_principios_ativos
for select
to anon, authenticated
using (true);

drop policy if exists apresentacoes_leitura_publica on catalogo.apresentacoes;
create policy apresentacoes_leitura_publica
on catalogo.apresentacoes
for select
to anon, authenticated
using (true);

grant usage on schema catalogo to anon, authenticated;
grant select on all tables in schema catalogo to anon, authenticated;
grant select on all sequences in schema catalogo to anon, authenticated;

alter default privileges in schema catalogo
grant select on tables to anon, authenticated;

alter default privileges in schema catalogo
grant select on sequences to anon, authenticated;
