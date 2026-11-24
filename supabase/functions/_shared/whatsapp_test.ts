import { deepStrictEqual as equal, ok } from "node:assert/strict";
import {
  alert,
  type Dependencies,
  HttpError,
  normalizePhone,
  report,
  reportPeriod,
  type Row,
  type SendRow,
  summarize,
} from "./whatsapp.ts";
import { webhook } from "./webhook.ts";
import { sendHandler } from "./send_handler.ts";

const actor = "11111111-1111-4111-8111-111111111111";
const patient = "22222222-2222-4222-8222-222222222222";
const requestId = "33333333-3333-4333-8333-333333333333";
const doseId = "44444444-4444-4444-8444-444444444444";
const alarmId = "55555555-5555-4555-8555-555555555555";
const now = new Date("2026-11-23T12:00:00.000Z");

function harness() {
  const queries: { table: string; query: Record<string, string> }[] = [];
  const rpcCalls: { name: string; args: Row }[] = [];
  const requests: { url: string; body: Row }[] = [];
  const sends = new Map<string, SendRow>();
  const deniedPhones = new Set<string>();
  const fixtures: Record<string, Row[]> = {
    cuidador_pacientes: [{ id: "vinculo" }],
    usuarios: [{ id: patient, nome: "Maria", telefone: "(45) 99999-9999" }],
    registro_doses: [{
      id: doseId,
      usuario_id: actor,
      alarme_id: alarmId,
      status: "perdida",
      horario_previsto: "2026-11-23T10:00:00Z",
    }],
    alarmes: [{ id: alarmId }],
    contatos_emergencia: [{ telefone: "(45) 98888-8888" }],
  };
  const deps: Dependencies = {
    config: {
      phoneId: "1002341972971180",
      token: "test-only-token",
      apiVersion: "v25.0",
      reportTemplate: "lembrebem_relatorio",
      alertTemplate: "lembrebem_dose_perdida",
      language: "pt_BR",
      appSecret: "test-only-app-secret",
      verifyToken: "test-only-verify-token",
    },
    authenticate: () => Promise.resolve(actor),
    now: () => now,
    db: {
      rows: (_schema, table, query) => {
        queries.push({ table, query });
        return Promise.resolve(fixtures[table] ?? []);
      },
      rpc<T>(name: string, args: Row): Promise<T> {
        rpcCalls.push({ name, args });
        let value: unknown = null;
        if (name === "whatsapp_reservar") {
          if (deniedPhones.has(String(args.p_telefone))) {
            value = { decision: "no_consent" };
          } else if (sends.has(String(args.p_chave))) {
            value = {
              decision: "existing",
              envio: sends.get(String(args.p_chave)),
            };
          } else {
            const envio: SendRow = {
              id: crypto.randomUUID(),
              status: "processing",
            };
            sends.set(String(args.p_chave), envio);
            value = { decision: "reserved", envio };
          }
        } else if (name === "whatsapp_finalizar") {
          const envio = [...sends.values()].find((s) => s.id === args.p_id)!;
          envio.status = args.p_status as SendRow["status"];
          envio.message_id = args.p_message_id as string | null;
          value = envio;
        }
        return Promise.resolve(value as T);
      },
    },
    fetch: (input, init) => {
      requests.push({
        url: String(input),
        body: JSON.parse(String(init?.body)),
      });
      return Promise.resolve(
        new Response(JSON.stringify({ messages: [{ id: "wamid.test" }] }), {
          status: 200,
        }),
      );
    },
  };
  return { deps, queries, rpcCalls, requests, fixtures, sends, deniedPhones };
}
function post(body: Row, authorization = "Bearer test-session"): Request {
  return new Request("https://example.invalid/function", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: authorization,
    },
    body: JSON.stringify(body),
  });
}
const reportBody = () => ({
  paciente_id: patient,
  dias: 7,
  request_id: requestId,
});
async function signed(
  payload: unknown,
  secret = "test-only-app-secret",
  suffix = "",
): Promise<Request> {
  const text = JSON.stringify(payload);
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(text)),
  );
  const hex = [...signature].map((b) => b.toString(16).padStart(2, "0")).join(
    "",
  );
  return new Request("https://example.invalid/webhook", {
    method: "POST",
    headers: {
      "x-hub-signature-256": `sha256=${hex}`,
      "Content-Type": "application/json",
    },
    body: text + suffix,
  });
}
function event(value: Row, phoneId = "1002341972971180"): Row {
  return {
    object: "whatsapp_business_account",
    entry: [{
      changes: [{
        field: "messages",
        value: { metadata: { phone_number_id: phoneId }, ...value },
      }],
    }],
  };
}

Deno.test("preflight dos envios libera navegador sem criar runtime nem exigir JWT", async () => {
  for (const handler of [report, alert]) {
    let runtimeCalls = 0;
    const serve = sendHandler(handler, () => {
      runtimeCalls++;
      throw new Error(
        "Preflight não deve consultar configuração ou credenciais",
      );
    });
    const response = await serve(
      new Request("https://example.invalid/function", {
        method: "OPTIONS",
        headers: {
          Origin: "http://localhost:7357",
          "Access-Control-Request-Method": "POST",
          "Access-Control-Request-Headers":
            "authorization,apikey,content-type,x-client-info",
        },
      }),
    );
    equal(response.status, 204);
    equal(await response.text(), "");
    equal(runtimeCalls, 0);
    equal(response.headers.get("Access-Control-Allow-Origin"), "*");
    equal(
      response.headers.get("Access-Control-Allow-Methods"),
      "POST, OPTIONS",
    );
    equal(
      response.headers.get("Access-Control-Allow-Headers"),
      "authorization, apikey, content-type, x-client-info",
    );
    equal(response.headers.get("Access-Control-Allow-Credentials"), null);
  }
});
Deno.test("CORS permite ler sucesso dos dois envios sem alterar o resultado", async () => {
  for (
    const [handler, body] of [[report, reportBody()], [alert, {
      dose_id: doseId,
    }]] as const
  ) {
    const h = harness();
    const response = await sendHandler(handler, () => h.deps)(post(body));
    equal(response.status, 200);
    equal(response.headers.get("Access-Control-Allow-Origin"), "*");
    equal(response.headers.get("Cache-Control"), "no-store");
    equal(
      response.headers.get("Content-Type"),
      "application/json; charset=utf-8",
    );
    equal((await response.json()).status, "accepted");
    equal(h.requests.length, 1);
  }
});
Deno.test("CORS preserva rejeicao JWT e expoe o erro ao navegador sem acesso ao banco", async () => {
  for (
    const [handler, body] of [[report, reportBody()], [alert, {
      dose_id: doseId,
    }]] as const
  ) {
    for (const authorization of ["", "Bearer invalid-session"]) {
      const h = harness();
      h.deps.authenticate = () =>
        Promise.reject(
          new HttpError(401, "UNAUTHORIZED", "Sessão inválida"),
        );
      const response = await sendHandler(handler, () => h.deps)(
        post(body, authorization),
      );
      equal(response.status, 401);
      equal(response.headers.get("Access-Control-Allow-Origin"), "*");
      equal((await response.json()).error, "UNAUTHORIZED");
      equal(h.queries.length, 0);
      equal(h.requests.length, 0);
    }
  }
});
Deno.test("erro ao criar runtime tambem retorna CORS e mensagem segura", async () => {
  for (const handler of [report, alert]) {
    const response = await sendHandler(handler, () => {
      throw new Error("Configuração interna sensível");
    })(post({}));
    equal(response.status, 500);
    equal(response.headers.get("Access-Control-Allow-Origin"), "*");
    const body = await response.json();
    equal(body.error, "INTERNAL_ERROR");
    ok(!JSON.stringify(body).includes("sensível"));
  }
});

Deno.test("relatorio exige sessao antes de consultar dados", async () => {
  const h = harness();
  const response = await report(post(reportBody(), ""), h.deps);
  equal(response.status, 401);
  equal(h.queries.length, 0);
  equal(h.requests.length, 0);
});
Deno.test("sessao invalida e rejeitada sem acesso ao banco", async () => {
  const h = harness();
  h.deps.authenticate = () =>
    Promise.reject(new HttpError(401, "UNAUTHORIZED", "Sessão inválida"));
  equal((await report(post(reportBody()), h.deps)).status, 401);
  equal(h.queries.length, 0);
});
Deno.test("telefone e texto arbitrarios do cliente sao rejeitados", async () => {
  const h = harness();
  equal(
    (await report(post({ ...reportBody(), telefone: "+15559999999" }), h.deps))
      .status,
    400,
  );
  equal(h.requests.length, 0);
});
Deno.test("cuidador sem vinculo nao pode enviar nem ler doses", async () => {
  const h = harness();
  h.fixtures.cuidador_pacientes = [];
  equal((await report(post(reportBody()), h.deps)).status, 403);
  equal(h.queries.map((q) => q.table), ["cuidador_pacientes"]);
  equal(h.requests.length, 0);
});
Deno.test("relatorio usa destinatario do banco, periodo limitado e separa atrasos", async () => {
  const h = harness();
  h.fixtures.registro_doses = ["tomada", "atrasada", "perdida", "pendente"].map(
    (status) => ({ status }),
  );
  const response = await report(post(reportBody()), h.deps);
  equal(response.status, 200);
  equal(await response.json(), {
    status: "accepted",
    message_id: "wamid.test",
  });
  equal(h.queries[0].query.cuidador_id, `eq.${actor}`);
  equal(h.queries[0].query.paciente_id, `eq.${patient}`);
  const doseQuery = h.queries.find((q) => q.table === "registro_doses")!.query;
  equal(
    doseQuery.and,
    "(horario_previsto.gte.2026-11-17T03:00:00.000Z,horario_previsto.lte.2026-11-23T12:00:00.000Z)",
  );
  equal(
    h.requests[0].url,
    "https://graph.facebook.com/v25.0/1002341972971180/messages",
  );
  equal(h.requests[0].body.to, "5545999999999");
  equal(
    h.requests[0].body.biz_opaque_callback_data,
    [...h.sends.values()][0].id,
  );
  const template = h.requests[0].body.template as {
    components: { parameters: { text: string }[] }[];
  };
  equal(template.components[0].parameters.map((p) => p.text), [
    "Maria",
    "17/11/2026 a 23/11/2026",
    "1",
    "1",
    "1",
    "1",
    "50%",
  ]);
});
Deno.test("falha de consulta nao envia relatorio parcial ou cache antigo", async () => {
  const h = harness();
  const read = h.deps.db.rows;
  h.deps.db.rows = (schema, table, query) =>
    table === "registro_doses"
      ? Promise.reject(
        new HttpError(503, "DATABASE_ERROR", "Dados indisponíveis"),
      )
      : read(schema, table, query);
  equal((await report(post(reportBody()), h.deps)).status, 503);
  equal(h.requests.length, 0);
});
Deno.test("paginacao consulta doses alem dos primeiros 500 registros", async () => {
  const h = harness();
  const read = h.deps.db.rows;
  const offsets: string[] = [];
  h.deps.db.rows = (schema, table, query) => {
    if (table !== "registro_doses") return read(schema, table, query);
    offsets.push(query.offset);
    return Promise.resolve(
      Array.from(
        { length: query.offset === "0" ? 500 : 1 },
        () => ({ status: "tomada" }),
      ),
    );
  };
  equal((await report(post(reportBody()), h.deps)).status, 200);
  equal(offsets, ["0", "500"]);
});
Deno.test("opt-in ausente bloqueia Meta", async () => {
  const h = harness();
  h.deniedPhones.add("5545999999999");
  const response = await report(post(reportBody()), h.deps);
  equal(response.status, 409);
  equal((await response.json()).error, "OPT_IN_REQUIRED");
  equal(h.requests.length, 0);
});
Deno.test("token nao configurado retorna erro seguro sem reservar envio", async () => {
  const h = harness();
  h.deps.config.token = "";
  const response = await report(post(reportBody()), h.deps);
  equal(response.status, 503);
  equal((await response.json()).error, "NOT_CONFIGURED");
  equal(h.rpcCalls.length, 0);
});
Deno.test("timeout fica unknown e mesma solicitacao nunca reenvia", async () => {
  const h = harness();
  let calls = 0;
  h.deps.fetch = () => {
    calls++;
    return Promise.reject(new Error("timeout"));
  };
  equal(
    (await (await report(post(reportBody()), h.deps)).json()).status,
    "unknown",
  );
  equal(
    (await (await report(post(reportBody()), h.deps)).json()).status,
    "unknown",
  );
  equal(calls, 1);
});
Deno.test("resposta HTTP 500 da Meta fica unknown para evitar duplicatas", async () => {
  const h = harness();
  h.deps.fetch = () =>
    Promise.resolve(new Response("server failed", { status: 500 }));
  equal(
    (await (await report(post(reportBody()), h.deps)).json()).status,
    "unknown",
  );
});
Deno.test("recusa HTTP 400 fica failed sem vazar corpo da Meta", async () => {
  const h = harness();
  h.deps.fetch = () =>
    Promise.resolve(
      new Response(
        JSON.stringify({ error: { code: 132001, message: "sensitive-token" } }),
        { status: 400 },
      ),
    );
  const body = await (await report(post(reportBody()), h.deps)).json();
  equal(body, { status: "failed" });
  equal(h.rpcCalls.at(-1)?.args.p_erro_codigo, "132001");
});
Deno.test("request_id em processamento nao causa segundo POST", async () => {
  const h = harness();
  h.sends.set(`relatorio:${actor}:${requestId}`, {
    id: requestId,
    status: "processing",
  });
  equal(
    (await (await report(post(reportBody()), h.deps)).json()).status,
    "processing",
  );
  equal(h.requests.length, 0);
});
Deno.test("periodo inicia meia-noite Sao Paulo e termina agora, sem futuro", () => {
  equal(reportPeriod(new Date("2026-11-23T01:30:00Z"), 1), {
    start: "2026-11-22T03:00:00.000Z",
    end: "2026-11-23T01:30:00.000Z",
    label: "22/11/2026 a 22/11/2026",
  });
  equal(summarize([]), {
    tomada: 0,
    atrasada: 0,
    perdida: 0,
    pendente: 0,
    total: 0,
    percentual: 0,
  });
});
Deno.test("normaliza Brasil sem duplicar 55 e preserva DDI explicito", () => {
  equal(normalizePhone("(45) 99999-9999"), "5545999999999");
  equal(normalizePhone("+55 (45) 99999-9999"), "5545999999999");
  equal(normalizePhone("5545999999999"), "5545999999999");
  equal(normalizePhone("+1 202 555 0100"), "12025550100");
  equal(normalizePhone("numero 123"), null);
  equal(normalizePhone(""), null);
});
Deno.test("alerta restringe dose e alarme ao dono autenticado", async () => {
  const h = harness();
  h.fixtures.alarmes = [];
  equal((await alert(post({ dose_id: doseId }), h.deps)).status, 403);
  equal(h.queries[0].query.usuario_id, `eq.${actor}`);
  equal(h.queries[1].query.usuario_id, `eq.${actor}`);
  equal(h.requests.length, 0);
});
Deno.test("dose tomada nao pode gerar aviso de dose perdida", async () => {
  const h = harness();
  h.fixtures.registro_doses[0].status = "tomada";
  equal((await alert(post({ dose_id: doseId }), h.deps)).status, 403);
  equal(h.requests.length, 0);
});
Deno.test("alerta deduplica telefones, ignora sem opt-in e nao recebe texto medico cliente", async () => {
  const h = harness();
  h.fixtures.contatos_emergencia = [{ telefone: "(45) 98888-8888" }, {
    telefone: "+5545988888888",
  }, { telefone: "(45) 97777-7777" }];
  h.deniedPhones.add("5545977777777");
  const response = await alert(post({ dose_id: doseId }), h.deps);
  equal(response.status, 200);
  const body = await response.json();
  equal(body.status, "partial");
  equal(body.accepted, 1);
  equal(body.skipped, 1);
  equal(h.requests.length, 1);
  equal(h.rpcCalls[0].args.p_chave, `alerta:${doseId}:5545988888888`);
});
Deno.test("alerta sem contato elegivel retorna skipped", async () => {
  const h = harness();
  h.fixtures.contatos_emergencia = [];
  equal(
    (await (await alert(post({ dose_id: doseId }), h.deps)).json()).status,
    "skipped",
  );
  equal(h.requests.length, 0);
});
Deno.test("webhook GET devolve challenge somente com verify token valido", async () => {
  const h = harness();
  const url =
    "https://example.invalid/webhook?hub.mode=subscribe&hub.challenge=1234&hub.verify_token=";
  equal(
    await (await webhook(new Request(url + h.deps.config.verifyToken), h.deps))
      .text(),
    "1234",
  );
  equal((await webhook(new Request(url + "wrong"), h.deps)).status, 403);
  equal(h.rpcCalls.length, 0);
});
Deno.test("webhook nao aceita assinatura ausente ou HMAC errado", async () => {
  const h = harness();
  equal((await webhook(post(event({})), h.deps)).status, 403);
  equal(
    (await webhook(await signed(event({}), "wrong-secret"), h.deps)).status,
    403,
  );
  equal(h.rpcCalls.length, 0);
});
Deno.test("webhook valida bytes originais e nao JSON reserializado", async () => {
  const h = harness();
  equal(
    (await webhook(
      await signed(event({}), h.deps.config.appSecret, " "),
      h.deps,
    )).status,
    403,
  );
  equal(h.rpcCalls.length, 0);
});
Deno.test("webhook ignora outro numero remetente mesmo com assinatura valida", async () => {
  const h = harness();
  const payload = event({
    messages: [{
      type: "text",
      from: "5545999999999",
      timestamp: "1795435200",
      text: { body: "ACEITO" },
    }],
  }, "another-number");
  equal((await webhook(await signed(payload), h.deps)).status, 200);
  equal(h.rpcCalls.length, 0);
});
Deno.test("webhook ACEITO e SAIR registram consentimento do remetente real", async () => {
  const h = harness();
  const payload = event({
    messages: [
      {
        type: "text",
        from: "5545999999999",
        timestamp: String(now.getTime() / 1000),
        text: { body: " ACEITO " },
      },
      {
        type: "text",
        from: "5545999999999",
        timestamp: String(now.getTime() / 1000 + 1),
        text: { body: "SAIR" },
      },
    ],
  });
  equal((await webhook(await signed(payload), h.deps)).status, 200);
  equal(h.rpcCalls.map((c) => [c.name, c.args.p_telefone, c.args.p_ativo]), [[
    "whatsapp_consentir",
    "5545999999999",
    true,
  ], ["whatsapp_consentir", "5545999999999", false]]);
});
Deno.test("webhook persiste status antes mesmo da resposta de envio existir", async () => {
  const h = harness();
  const payload = event({
    statuses: [{
      id: "wamid.race",
      status: "read",
      timestamp: String(now.getTime() / 1000),
    }],
  });
  equal((await webhook(await signed(payload), h.deps)).status, 200);
  equal(h.rpcCalls[0], {
    name: "whatsapp_registrar_evento",
    args: {
      p_message_id: "wamid.race",
      p_status: "read",
      p_evento_em: now.toISOString(),
      p_erro_codigo: null,
      p_envio_id: null,
      p_telefone: null,
    },
  });
});
Deno.test("falha ao persistir webhook retorna erro para Meta repetir", async () => {
  const h = harness();
  h.deps.db.rpc = () =>
    Promise.reject(new HttpError(503, "DATABASE_ERROR", "Banco indisponível"));
  const payload = event({
    statuses: [{
      id: "wamid.retry",
      status: "delivered",
      timestamp: String(now.getTime() / 1000),
    }],
  });
  equal((await webhook(await signed(payload), h.deps)).status, 503);
});
Deno.test("limita corpo de requisicoes antes de processar eventos", async () => {
  const h = harness();
  const req = new Request("https://example.invalid/webhook", {
    method: "POST",
    body: "x",
    headers: { "content-length": "1048577" },
  });
  equal((await webhook(req, h.deps)).status, 413);
  equal(h.rpcCalls.length, 0);
});
Deno.test("payload assinado mas invalido nao executa operacoes", async () => {
  const h = harness();
  equal(
    (await webhook(await signed({ object: "other-object" }), h.deps)).status,
    400,
  );
  equal(h.rpcCalls.length, 0);
});
Deno.test("nao permite GET em endpoint de envio", async () => {
  const h = harness();
  equal(
    (await report(new Request("https://example.invalid"), h.deps)).status,
    405,
  );
  ok(!h.requests.length);
});

Deno.test("webhook transmite correlacao opaca e destinatario validados", async () => {
  const h = harness();
  const payload = event({
    statuses: [{
      id: "wamid.unknown-resolved",
      status: "delivered",
      timestamp: String(now.getTime() / 1000),
      recipient_id: "5545999999999",
      biz_opaque_callback_data: requestId,
    }],
  });
  equal((await webhook(await signed(payload), h.deps)).status, 200);
  equal(h.rpcCalls[0].args.p_envio_id, requestId);
  equal(h.rpcCalls[0].args.p_telefone, "5545999999999");
});

Deno.test("alertas limitam concorrencia e continuam apos falha de um contato", async () => {
  const h = harness();
  h.fixtures.contatos_emergencia = Array.from(
    { length: 10 },
    (_, i) => ({ telefone: `+554599999999${i}` }),
  );
  let active = 0;
  let maximum = 0;
  let calls = 0;
  h.deps.fetch = async () => {
    active++;
    maximum = Math.max(maximum, active);
    const index = calls++;
    await new Promise((resolve) => setTimeout(resolve, 2));
    active--;
    if (index === 0) throw new Error("timeout");
    return new Response(
      JSON.stringify({ messages: [{ id: `wamid.${index}` }] }),
    );
  };
  const response = await alert(post({ dose_id: doseId }), h.deps);
  const body = await response.json();
  equal(calls, 10);
  ok(maximum <= 5);
  ok(maximum > 1);
  equal(body.status, "partial");
  equal(body.accepted, 9);
  equal(body.unknown, 1);
});

Deno.test("mais de dez contatos nao causa truncamento silencioso", async () => {
  const h = harness();
  h.fixtures.contatos_emergencia = Array.from(
    { length: 11 },
    () => ({ telefone: "(45) 99999-9999" }),
  );
  equal((await alert(post({ dose_id: doseId }), h.deps)).status, 400);
  equal(h.requests.length, 0);
});
