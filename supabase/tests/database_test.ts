import { PGlite } from "npm:@electric-sql/pglite@0.5.13";

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Esperado ${JSON.stringify(expected)}, recebido ${
        JSON.stringify(actual)
      }`,
    );
  }
}

Deno.test("WhatsApp: migracao real, privilegios, deduplicacao e reconciliacao", async (t) => {
  const db = new PGlite();
  try {
    await db.exec(`
      create role anon;
      create role authenticated;
      create role service_role bypassrls;
      create schema app;
      create table app.usuarios(id uuid primary key);
      create table app.cuidador_pacientes(id uuid primary key);
      create table app.registro_doses(id uuid primary key);
      create table app.alarmes(id uuid primary key);
      create table app.contatos_emergencia(id uuid primary key);
    `);
    await db.exec(
      await Deno.readTextFile(
        new URL(
          "../migrations/20261123194036_whatsapp_meta.sql",
          import.meta.url,
        ),
      ),
    );
    const actor = "11111111-1111-4111-8111-111111111111";
    const patient = "22222222-2222-4222-8222-222222222222";
    const phone = "5545999990000";
    async function value(sql: string, params: unknown[] = []) {
      const result = await db.query<{ value: unknown }>(sql, params);
      return result.rows[0]?.value;
    }
    async function reserve(
      key: string,
      context = "7:2026-11-23",
      requestedBy = actor,
      type = "relatorio",
    ) {
      return await value(
        "select public.whatsapp_reservar($1,$2,$3,$4,$5,$6) as value",
        [key, requestedBy, patient, type, phone, context],
      ) as { decision: string; envio: { id: string; status: string } };
    }
    async function consent(active: boolean, timestamp: string) {
      await db.query("select public.whatsapp_consentir($1,$2,$3)", [
        phone,
        active,
        timestamp,
      ]);
    }
    async function mustFail(sql: string, params: unknown[] = []) {
      let failed = false;
      try {
        await db.query(sql, params);
      } catch {
        failed = true;
      }
      equal(failed, true);
    }

    await t.step("Todas as tabelas novas possuem RLS", async () => {
      equal(
        await value(
          "select bool_and(relrowsecurity) as value from pg_class where relname in ('whatsapp_envios','whatsapp_eventos','whatsapp_consentimentos')",
        ),
        true,
      );
    });
    await t.step(
      "Anonimo e usuario autenticado nao podem acessar tabelas nem RPCs",
      async () => {
        for (const role of ["anon", "authenticated"]) {
          for (
            const table of [
              "whatsapp_envios",
              "whatsapp_eventos",
              "whatsapp_consentimentos",
            ]
          ) {
            equal(
              await value(
                "select has_table_privilege($1,$2,'SELECT,INSERT,UPDATE,DELETE') as value",
                [role, `public.${table}`],
              ),
              false,
            );
          }
          equal(
            await value(
              "select bool_or(has_function_privilege($1,p.oid,'EXECUTE')) as value from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname like 'whatsapp_%'",
              [role],
            ),
            false,
          );
          await db.exec(`set role ${role}`);
          await mustFail("select * from public.whatsapp_envios");
          await mustFail(
            "select public.whatsapp_consentir('5545999990000',true,now())",
          );
          await db.exec("reset role");
        }
      },
    );
    await t.step(
      "RLS protege mesmo se um grant SELECT for adicionado por engano",
      async () => {
        await db.exec(
          "insert into public.whatsapp_consentimentos values ('5545888880000',true,now(),now()); grant select on public.whatsapp_consentimentos to authenticated; set role authenticated;",
        );
        equal(
          await value(
            "select count(*)::int as value from public.whatsapp_consentimentos",
          ),
          0,
        );
        await db.exec(
          "reset role; revoke select on public.whatsapp_consentimentos from authenticated;",
        );
      },
    );
    await db.exec("set role service_role");
    await t.step(
      "Sem aceite nao reserva nem consome limite de envio",
      async () => {
        equal((await reserve("request-1")).decision, "no_consent");
        equal(
          await value(
            "select count(*)::int as value from public.whatsapp_envios",
          ),
          0,
        );
      },
    );
    let sendId = "";
    await t.step("Aceite permite reservar uma unica mensagem", async () => {
      await consent(true, "2026-11-23T10:00:00Z");
      const result = await reserve("request-1");
      equal(result.decision, "reserved");
      equal(result.envio.status, "processing");
      sendId = result.envio.id;
      equal((await reserve("request-1")).envio.id, sendId);
      equal((await reserve("request-1")).decision, "existing");
      equal(
        await value(
          "select count(*)::int as value from public.whatsapp_envios",
        ),
        1,
      );
    });
    await t.step(
      "Reuso da chave para outro contexto ou usuario e rejeitado",
      async () => {
        equal(
          (await reserve("request-1", "30:2026-11-23")).decision,
          "conflict",
        );
        equal(
          (await reserve(
            "request-1",
            undefined,
            "33333333-3333-4333-8333-333333333333",
          )).decision,
          "conflict",
        );
      },
    );
    await t.step(
      "Outro request_id nao contorna o cooldown do relatorio",
      async () => {
        equal((await reserve("request-2")).decision, "rate_limited");
      },
    );
    await t.step(
      "Processamento abandonado torna-se desconhecido sem reenvio",
      async () => {
        await db.query(
          "update public.whatsapp_envios set criado_em=now()-interval '3 minutes' where id=$1",
          [sendId],
        );
        const result = await reserve("request-1");
        equal(result.decision, "existing");
        equal(result.envio.status, "unknown");
      },
    );
    await t.step(
      "Webhook anterior a resposta da Meta e conciliado",
      async () => {
        await db.query(
          "select public.whatsapp_registrar_evento($1,'read',now())",
          ["wamid.race"],
        );
        const result = await value(
          "select public.whatsapp_finalizar($1,'accepted',$2) as value",
          [sendId, "wamid.race"],
        ) as { status: string };
        equal(result.status, "read");
      },
    );
    await t.step(
      "Eventos repetidos ou fora de ordem nao regridem mensagem lida",
      async () => {
        for (const status of ["sent", "delivered", "failed", "read", "sent"]) {
          await db.query(
            "select public.whatsapp_registrar_evento($1,$2,now())",
            ["wamid.race", status],
          );
        }
        equal(
          await value(
            "select status as value from public.whatsapp_envios where id=$1",
            [sendId],
          ),
          "read",
        );
        equal(
          await value(
            "select count(*)::int as value from public.whatsapp_eventos where message_id='wamid.race'",
          ),
          1,
        );
        await db.query("select public.whatsapp_finalizar($1,'unknown')", [
          sendId,
        ]);
        equal(
          await value(
            "select status as value from public.whatsapp_envios where id=$1",
            [sendId],
          ),
          "read",
        );
      },
    );
    await t.step(
      "ID de mensagem divergente nao substitui o ID original",
      async () => {
        await mustFail(
          "select public.whatsapp_finalizar($1,'accepted','wamid.outro')",
          [sendId],
        );
        equal(
          await value(
            "select message_id as value from public.whatsapp_envios where id=$1",
            [sendId],
          ),
          "wamid.race",
        );
      },
    );
    await t.step(
      "Revogacao prevalece sobre aceite antigo ou com mesmo timestamp",
      async () => {
        await consent(false, "2026-11-23T11:00:00Z");
        await consent(true, "2026-11-23T10:00:00Z");
        await consent(true, "2026-11-23T11:00:00Z");
        equal(
          await value(
            "select ativo as value from public.whatsapp_consentimentos where telefone=$1",
            [phone],
          ),
          false,
        );
        equal(
          (await reserve("request-new", "1:2026-11-23")).decision,
          "no_consent",
        );
        await consent(true, "2026-11-23T12:00:00Z");
        equal(
          await value(
            "select ativo as value from public.whatsapp_consentimentos where telefone=$1",
            [phone],
          ),
          true,
        );
      },
    );
    await t.step("Alerta da mesma dose nao e reenviado", async () => {
      const first = await reserve("alert-dose-1", "dose-1", actor, "alerta");
      equal(first.decision, "reserved");
      equal(
        (await reserve("alert-dose-1", "dose-1", actor, "alerta")).decision,
        "existing",
      );
    });
    await t.step(
      "Callback recupera timeout pelo ID da reserva e destinatario",
      async () => {
        const pending = await reserve(
          "callback-timeout",
          "callback-timeout",
          actor,
          "alerta",
        );
        await db.query("select public.whatsapp_finalizar($1,'unknown')", [
          pending.envio.id,
        ]);
        await db.query(
          "select public.whatsapp_registrar_evento($1,'delivered',now(),null,$2,$3)",
          [
            "wamid.timeout",
            pending.envio.id,
            phone,
          ],
        );
        const actual = await value(
          "select jsonb_build_object('status',status,'message_id',message_id) as value from public.whatsapp_envios where id=$1",
          [pending.envio.id],
        );
        equal(actual, { status: "delivered", message_id: "wamid.timeout" });
        equal(
          (await reserve(
            "callback-timeout",
            "callback-timeout",
            actor,
            "alerta",
          )).decision,
          "existing",
        );
        const finalized = await value(
          "select public.whatsapp_finalizar($1,'unknown') as value",
          [pending.envio.id],
        ) as { status: string };
        equal(finalized.status, "delivered");
      },
    );
    await t.step(
      "Callback opaco nao associa telefone divergente ou substitui mensagem",
      async () => {
        const pending = await reserve(
          "callback-mismatch",
          "callback-mismatch",
          actor,
          "alerta",
        );
        await db.query(
          "select public.whatsapp_registrar_evento($1,'read',now(),null,$2,$3)",
          [
            "wamid.wrong-recipient",
            pending.envio.id,
            "5545999999999",
          ],
        );
        equal(
          await value(
            "select status as value from public.whatsapp_envios where id=$1",
            [pending.envio.id],
          ),
          "processing",
        );
        await db.query(
          "select public.whatsapp_registrar_evento($1,'sent',now(),null,$2,$3)",
          [
            "wamid.correct",
            pending.envio.id,
            phone,
          ],
        );
        await db.query(
          "select public.whatsapp_registrar_evento($1,'read',now(),null,$2,$3)",
          [
            "wamid.replacement",
            pending.envio.id,
            phone,
          ],
        );
        equal(
          await value(
            "select message_id as value from public.whatsapp_envios where id=$1",
            [pending.envio.id],
          ),
          "wamid.correct",
        );
        equal(
          await value(
            "select status as value from public.whatsapp_envios where id=$1",
            [pending.envio.id],
          ),
          "sent",
        );
        await db.query(
          "select public.whatsapp_registrar_evento($1,'read',now(),null,$2,$3)",
          [
            "wamid.correct",
            pending.envio.id,
            "5545999999999",
          ],
        );
        equal(
          await value(
            "select status as value from public.whatsapp_envios where id=$1",
            [pending.envio.id],
          ),
          "sent",
        );
      },
    );
    await t.step(
      "Limite por usuario bloqueia o vigesimo primeiro envio",
      async () => {
        const otherActor = "44444444-4444-4444-8444-444444444444";
        for (let i = 0; i < 20; i++) {
          equal(
            (await reserve(`rate-${i}`, `dose-${i}`, otherActor, "alerta"))
              .decision,
            "reserved",
          );
        }
        equal(
          (await reserve(
            "rate-overflow",
            "dose-overflow",
            otherActor,
            "alerta",
          )).decision,
          "rate_limited",
        );
      },
    );
    await t.step(
      "Status e telefone invalidos sao rejeitados pelo banco",
      async () => {
        await mustFail(
          "select public.whatsapp_registrar_evento('wamid.bad','qualquer',now())",
        );
        await mustFail(
          "select public.whatsapp_consentir('1002341972971180',true,now())",
        );
        await mustFail("select public.whatsapp_finalizar($1,'delivered')", [
          sendId,
        ]);
      },
    );
  } finally {
    await db.close();
  }
});
