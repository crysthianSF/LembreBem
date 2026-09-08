do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'catalogo'
      and table_name = 'medicamentos'
      and table_type = 'BASE TABLE'
  ) then
    execute 'alter table catalogo.medicamentos rename to medicamentos_legado';
  end if;

  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'catalogo'
      and table_name = 'bulas'
      and table_type = 'BASE TABLE'
  ) then
    execute 'alter table catalogo.bulas rename to bulas_legado';
  end if;

  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'catalogo'
      and table_name = 'nomes_base'
      and table_type = 'BASE TABLE'
  ) then
    execute 'alter table catalogo.nomes_base rename to nomes_base_legado';
  end if;
end;
$$;

drop view if exists catalogo.medicamentos;

comment on schema catalogo is
'Schema de catalogo de medicamentos. Tabelas antigas podem permanecer com sufixo _legado para consulta historica.';
