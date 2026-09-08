-- Consultas de apoio para validar o que a API do catalogo esta lendo.
-- Rode no SQL Editor do Supabase quando quiser comparar o app com a base.

-- 1. Buscar por termo, parecido com GET /api/medicamentos/busca?termo=parace
select
  id,
  medicamento_id,
  nome_produto,
  principio_ativo,
  concentracao_dosagem,
  apresentacao,
  fabricante,
  tipo_medicamento,
  tarja,
  preco,
  registro,
  ean
from catalogo.medicamentos
where nome_produto_normalizado like '%parace%'
   or principio_ativo_normalizado like '%parace%'
order by nome_produto asc, apresentacao asc
limit 30;

-- 2. Conferir um medicamento especifico por id, parecido com GET /api/medicamentos/:id
select *
from catalogo.medicamentos
where id = 16;

-- 3. Conferir um medicamento por registro, parecido com GET /api/medicamentos/registro/:registro
select *
from catalogo.medicamentos
where registro = '1004307850011';

-- 4. Ver o que esta salvo para o usuario e se o id antigo ainda aponta corretamente
select
  um.id as usuario_medicamento_id,
  um.usuario_id,
  um.medicamento_id,
  um.apelido,
  m.id as catalogo_id,
  m.nome_produto,
  m.principio_ativo,
  m.concentracao_dosagem,
  m.apresentacao,
  m.fabricante,
  m.registro
from app.usuario_medicamentos um
left join catalogo.medicamentos m
  on m.id = um.medicamento_id
order by um.created_at desc;

-- 5. Resumo rapido de correspondencia entre usuario_medicamentos e catalogo.medicamentos
select
  count(*)::int as total_salvos,
  count(*) filter (where m.id is not null)::int as com_correspondencia,
  count(*) filter (where m.id is null)::int as sem_correspondencia
from app.usuario_medicamentos um
left join catalogo.medicamentos m
  on m.id = um.medicamento_id;
