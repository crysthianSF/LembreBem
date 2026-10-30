-- Ponto 1 de SEC-01: Tabela de convites seguros e emissão restrita ao paciente
create table if not exists app.convites_vinculacao (
    id uuid primary key default gen_random_uuid(),
    paciente_id uuid not null references app.usuarios(id) on delete cascade,
    cuidador_id uuid not null references app.cuidadores(id) on delete cascade,
    token_hash text not null unique,
    criado_em timestamptz not null default now(),
    expira_em timestamptz not null default (now() + interval '15 minutes'),
    consumido_em timestamptz,
    revogado_em timestamptz
);

alter table app.convites_vinculacao enable row level security;

drop policy if exists convites_proprios_paciente on app.convites_vinculacao;
create policy convites_proprios_paciente on app.convites_vinculacao
    for select to authenticated
    using (paciente_id = auth.uid());

create or replace function app.emitir_convite_paciente(
    p_cuidador_id uuid,
    p_token_hash text
)
returns uuid
language plpgsql
security definer
set search_path = app, public
as $$
declare
    v_paciente_id uuid;
    v_convite_id uuid;
begin
    v_paciente_id := auth.uid();
    
    if v_paciente_id is null then
        raise exception 'Operação não autorizada: sessão ausente.';
    end if;

    if v_paciente_id = p_cuidador_id then
        raise exception 'Um paciente não pode emitir convite para si mesmo.';
    end if;

    if not exists (select 1 from app.cuidadores where id = p_cuidador_id) then
        raise exception 'Destinatário informado não é um cuidador válido.';
    end if;

    update app.convites_vinculacao
    set revogado_em = now()
    where paciente_id = v_paciente_id
      and cuidador_id = p_cuidador_id
      and consumido_em is null
      and revogado_em is null;

    insert into app.convites_vinculacao (
        paciente_id,
        cuidador_id,
        token_hash,
        expira_em
    )
    values (
        v_paciente_id,
        p_cuidador_id,
        p_token_hash,
        now() + interval '15 minutes'
    )
    returning id into v_convite_id;

    return v_convite_id;
end;
$$;

revoke execute on function app.emitir_convite_paciente(uuid, text) from public;
grant execute on function app.emitir_convite_paciente(uuid, text) to authenticated;