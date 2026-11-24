-- Somente infraestrutura WhatsApp. Nao altera RLS/constraints das tabelas do app.
create table public.whatsapp_consentimentos (
  telefone text primary key check (telefone ~ '^[1-9][0-9]{7,14}$'),
  ativo boolean not null,
  evento_em timestamptz not null,
  atualizado_em timestamptz not null default now()
);

create table public.whatsapp_envios (
  id uuid primary key default gen_random_uuid(),
  chave text not null unique,
  solicitante_id uuid not null,
  paciente_id uuid not null,
  tipo text not null check (tipo in ('relatorio', 'alerta')),
  telefone text not null check (telefone ~ '^[1-9][0-9]{7,14}$'),
  contexto text not null,
  status text not null default 'processing' check (
    status in ('processing','unknown','accepted','sent','delivered','read','failed')),
  message_id text unique,
  erro_codigo text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index whatsapp_envios_solicitante_criado on public.whatsapp_envios(solicitante_id, criado_em desc);
create index whatsapp_envios_telefone_criado on public.whatsapp_envios(telefone, criado_em desc);

-- Armazena somente status, nunca o corpo do relatorio ou a mensagem recebida.
-- Eventos anteriores a resposta do POST /messages serao conciliados ao finalizar.
create table public.whatsapp_eventos (
  message_id text primary key,
  envio_id uuid,
  telefone text check (telefone is null or telefone ~ '^[1-9][0-9]{7,14}$'),
  status text not null check (status in ('sent','delivered','read','failed')),
  evento_em timestamptz not null,
  erro_codigo text,
  recebido_em timestamptz not null default now()
);

alter table public.whatsapp_consentimentos enable row level security;
alter table public.whatsapp_envios enable row level security;
alter table public.whatsapp_eventos enable row level security;
revoke all on public.whatsapp_consentimentos, public.whatsapp_envios, public.whatsapp_eventos from public, anon, authenticated;
grant select, insert, update, delete on public.whatsapp_consentimentos, public.whatsapp_envios, public.whatsapp_eventos to service_role;
grant usage on schema app to service_role;
grant select on app.usuarios, app.cuidador_pacientes, app.registro_doses, app.alarmes, app.contatos_emergencia to service_role;

create function public.whatsapp_status_ordem(p_status text) returns integer
language sql immutable strict security invoker set search_path = '' as $$
  select case p_status when 'processing' then 0 when 'unknown' then 1
    when 'accepted' then 2 when 'sent' then 3 when 'failed' then 4
    when 'delivered' then 5 when 'read' then 6 else -1 end;
$$;

create function public.whatsapp_consentir(p_telefone text, p_ativo boolean, p_evento_em timestamptz)
returns void language sql security invoker set search_path = '' as $$
  insert into public.whatsapp_consentimentos(telefone,ativo,evento_em)
  values(p_telefone,p_ativo,p_evento_em)
  on conflict(telefone) do update set ativo=excluded.ativo, evento_em=excluded.evento_em, atualizado_em=now()
  where excluded.evento_em > whatsapp_consentimentos.evento_em
     or (excluded.evento_em = whatsapp_consentimentos.evento_em and not excluded.ativo);
$$;

create function public.whatsapp_reservar(
  p_chave text, p_solicitante_id uuid, p_paciente_id uuid, p_tipo text,
  p_telefone text, p_contexto text
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare v_envio public.whatsapp_envios; v_consentimento boolean;
begin
  -- Serializa duplicatas e limites por solicitante, inclusive chamadas concorrentes.
  perform pg_advisory_xact_lock(hashtextextended(p_solicitante_id::text, 17));
  perform pg_advisory_xact_lock(hashtextextended(p_chave, 18));
  select * into v_envio from public.whatsapp_envios where chave=p_chave;
  if found then
    if v_envio.solicitante_id <> p_solicitante_id or v_envio.paciente_id <> p_paciente_id
       or v_envio.tipo <> p_tipo or v_envio.telefone <> p_telefone or v_envio.contexto <> p_contexto then
      return jsonb_build_object('decision','conflict');
    end if;
    if v_envio.status='processing' and v_envio.criado_em < now()-interval '2 minutes' then
      update public.whatsapp_envios set status='unknown',atualizado_em=now()
      where id=v_envio.id returning * into v_envio;
    end if;
    return jsonb_build_object('decision','existing','envio',to_jsonb(v_envio));
  end if;
  select ativo into v_consentimento from public.whatsapp_consentimentos where telefone=p_telefone for share;
  if v_consentimento is distinct from true then
    return jsonb_build_object('decision','no_consent');
  end if;
  if (select count(*) from public.whatsapp_envios where solicitante_id=p_solicitante_id and criado_em > now()-interval '10 minutes') >= 20 then
    return jsonb_build_object('decision','rate_limited');
  end if;
  -- Um relatorio para o mesmo paciente/periodo por minuto, mesmo com outro request_id.
  if p_tipo='relatorio' and exists(select 1 from public.whatsapp_envios
      where solicitante_id=p_solicitante_id and paciente_id=p_paciente_id and tipo='relatorio'
        and contexto=p_contexto and criado_em > now()-interval '1 minute') then
    return jsonb_build_object('decision','rate_limited');
  end if;
  insert into public.whatsapp_envios(chave,solicitante_id,paciente_id,tipo,telefone,contexto)
  values(p_chave,p_solicitante_id,p_paciente_id,p_tipo,p_telefone,p_contexto)
  returning * into v_envio;
  return jsonb_build_object('decision','reserved','envio',to_jsonb(v_envio));
end;
$$;

create function public.whatsapp_finalizar(p_id uuid,p_status text,p_message_id text default null,p_erro_codigo text default null)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare v_envio public.whatsapp_envios; v_evento public.whatsapp_eventos;
begin
  if p_status not in ('accepted','failed','unknown') then raise exception 'Invalid final status'; end if;
  if p_message_id is not null then perform pg_advisory_xact_lock(hashtextextended(p_message_id,19)); end if;
  select * into v_envio from public.whatsapp_envios where id=p_id for update;
  if not found then raise exception 'Unknown send'; end if;
  if p_message_id is not null and v_envio.message_id is not null and p_message_id<>v_envio.message_id then raise exception 'Message mismatch'; end if;
  if public.whatsapp_status_ordem(p_status)>public.whatsapp_status_ordem(v_envio.status) then
    v_envio.status:=p_status;
    v_envio.erro_codigo:=p_erro_codigo;
  end if;
  v_envio.message_id:=coalesce(v_envio.message_id,p_message_id);
  select * into v_evento from public.whatsapp_eventos where message_id=v_envio.message_id
    and (telefone is null or telefone=v_envio.telefone)
    and (envio_id is null or envio_id=v_envio.id);
  if found and public.whatsapp_status_ordem(v_evento.status)>public.whatsapp_status_ordem(v_envio.status) then
    v_envio.status:=v_evento.status; v_envio.erro_codigo:=v_evento.erro_codigo;
  end if;
  update public.whatsapp_envios set status=v_envio.status,message_id=v_envio.message_id,
    erro_codigo=v_envio.erro_codigo,atualizado_em=now() where id=p_id returning * into v_envio;
  return to_jsonb(v_envio);
end;
$$;

create function public.whatsapp_registrar_evento(p_message_id text,p_status text,p_evento_em timestamptz,
  p_erro_codigo text default null,p_envio_id uuid default null,p_telefone text default null)
returns void language plpgsql security invoker set search_path = '' as $$
declare v_envio public.whatsapp_envios;
begin
  if p_status not in ('sent','delivered','read','failed') then raise exception 'Invalid event status'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_message_id,19));
  if exists(select 1 from public.whatsapp_envios
      where (id=p_envio_id or message_id=p_message_id)
        and ((p_telefone is not null and telefone<>p_telefone)
          or (message_id is not null and message_id<>p_message_id))) then
    return;
  end if;
  -- O callback opaco foi criado pelo servidor. Correlacao exige tambem destinatario.
  -- Permite recuperar accepted/unknown mesmo se a resposta HTTP da Meta se perdeu.
  select * into v_envio from public.whatsapp_envios
  where (message_id=p_message_id or (id=p_envio_id and p_telefone is not null and telefone=p_telefone))
    and (message_id is null or message_id=p_message_id)
    and (p_telefone is null or telefone=p_telefone)
  for update;
  insert into public.whatsapp_eventos(message_id,envio_id,telefone,status,evento_em,erro_codigo)
  values(p_message_id,v_envio.id,p_telefone,p_status,p_evento_em,p_erro_codigo)
  on conflict(message_id) do update set status=excluded.status,evento_em=excluded.evento_em,
    erro_codigo=excluded.erro_codigo,envio_id=coalesce(excluded.envio_id,whatsapp_eventos.envio_id),
    telefone=coalesce(excluded.telefone,whatsapp_eventos.telefone),recebido_em=now()
  where (whatsapp_eventos.telefone is null or excluded.telefone is null or whatsapp_eventos.telefone=excluded.telefone)
    and (public.whatsapp_status_ordem(excluded.status)>public.whatsapp_status_ordem(whatsapp_eventos.status)
      or (excluded.status=whatsapp_eventos.status and excluded.evento_em>whatsapp_eventos.evento_em));
  update public.whatsapp_envios set status=e.status,message_id=e.message_id,erro_codigo=e.erro_codigo,atualizado_em=now()
  from public.whatsapp_eventos e where whatsapp_envios.id=v_envio.id and e.message_id=p_message_id
    and (e.telefone is null or e.telefone=whatsapp_envios.telefone)
    and (e.envio_id is null or e.envio_id=whatsapp_envios.id)
    and public.whatsapp_status_ordem(e.status)>public.whatsapp_status_ordem(whatsapp_envios.status);
end;
$$;

revoke all on function public.whatsapp_status_ordem(text) from public, anon, authenticated;
revoke all on function public.whatsapp_consentir(text,boolean,timestamptz) from public, anon, authenticated;
revoke all on function public.whatsapp_reservar(text,uuid,uuid,text,text,text) from public, anon, authenticated;
revoke all on function public.whatsapp_finalizar(uuid,text,text,text) from public, anon, authenticated;
revoke all on function public.whatsapp_registrar_evento(text,text,timestamptz,text,uuid,text) from public, anon, authenticated;
grant execute on function public.whatsapp_status_ordem(text),
  public.whatsapp_consentir(text,boolean,timestamptz),
  public.whatsapp_reservar(text,uuid,uuid,text,text,text),
  public.whatsapp_finalizar(uuid,text,text,text),
  public.whatsapp_registrar_evento(text,text,timestamptz,text,uuid,text) to service_role;
