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

create table if not exists app.tentativas_vinculacao (
    id uuid primary key default gen_random_uuid(),
    usuario_id uuid not null references app.cuidadores(id) on delete cascade,
    sucesso boolean not null default false,
    tentado_em timestamptz not null default now()
);

alter table app.tentativas_vinculacao enable row level security;
revoke all on app.tentativas_vinculacao from public, anon, authenticated;

create or replace function app.verificar_rate_limit_cuidador(p_cuidador_id uuid)
returns boolean
language plpgsql
security definer
set search_path = app, public
as $$
declare
    v_erros_recentes int;
begin
    select count(*) into v_erros_recentes
    from app.tentativas_vinculacao
    where usuario_id = p_cuidador_id
      and sucesso = false
      and tentado_em > (now() - interval '15 minutes');

    if v_erros_recentes >= 5 then
        return false;
    end if;

    return true;
end;
$$;

create or replace function app.vincular_paciente(codigo text)
returns uuid
language plpgsql
security definer
set search_path = app, public
as $$
begin
    raise exception 'Este método foi descontinuado permanentemente por segurança (SEC-01). Utilize o fluxo seguro de convites temporários.';
end;
$$;

revoke execute on function app.vincular_paciente(text) from public;
grant execute on function app.vincular_paciente(text) to authenticated;

create or replace function app.consumir_convite_cuidador(
    p_token_hash text
)
returns boolean
language plpgsql
security definer
set search_path = app, public
as $$
declare
    v_cuidador_id uuid;
    v_convite record;
begin
    v_cuidador_id := auth.uid();
    if v_cuidador_id is null then
        raise exception 'Operação não autorizada: sessão ausente.';
    end if;

    if not exists (select 1 from app.cuidadores where id = v_cuidador_id) then
        raise exception 'Apenas cuidadores cadastrados podem aceitar convites.';
    end if;

    if not app.verificar_rate_limit_cuidador(v_cuidador_id) then
        raise exception 'Limite de tentativas excedido. Tente novamente em 15 minutos.';
    end if;

    select * into v_convite
    from app.convites_vinculacao
    where token_hash = p_token_hash
    for update;

    if v_convite.id is null 
       or v_convite.cuidador_id <> v_cuidador_id
       or v_convite.expira_em < now()
       or v_convite.consumido_em is not null
       or v_convite.revogado_em is not null then

        insert into app.tentativas_vinculacao (usuario_id, sucesso) 
        values (v_cuidador_id, false);
        
        raise exception 'Convite inválido, expirado ou não autorizado para esta conta.';
    end if;

    update app.convites_vinculacao
    set consumido_em = now()
    where id = v_convite.id;

    insert into app.cuidador_pacientes (cuidador_id, paciente_id)
    values (v_cuidador_id, v_convite.paciente_id)
    on conflict (cuidador_id, paciente_id) do update set vinculado_em = now();

    insert into app.tentativas_vinculacao (usuario_id, sucesso) 
    values (v_cuidador_id, true);

    return true;
end;
$$;

revoke execute on function app.consumir_convite_cuidador(text) from public;
grant execute on function app.consumir_convite_cuidador(text) to authenticated;