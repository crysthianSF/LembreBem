export type SendStatus =
  | "processing"
  | "unknown"
  | "accepted"
  | "sent"
  | "delivered"
  | "read"
  | "failed";
export type Row = Record<string, unknown>;
export interface SendRow extends Row {
  id: string;
  status: SendStatus;
  message_id?: string | null;
}
export interface Reservation {
  decision:
    | "reserved"
    | "existing"
    | "conflict"
    | "no_consent"
    | "rate_limited";
  envio?: SendRow;
}
export interface Repository {
  rows(
    schema: string,
    table: string,
    query: Record<string, string>,
  ): Promise<Row[]>;
  rpc<T>(name: string, args: Row): Promise<T>;
}
export interface Config {
  phoneId: string;
  token: string;
  apiVersion: string;
  reportTemplate: string;
  alertTemplate: string;
  language: string;
  verifyToken: string;
  appSecret: string;
}
export interface Dependencies {
  db: Repository;
  config: Config;
  authenticate(token: string): Promise<string>;
  fetch: typeof fetch;
  now(): Date;
}
export class HttpError extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(message);
  }
}
const headers = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
};
export function json(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), { status, headers });
}
export function errorResponse(error: unknown): Response {
  if (error instanceof HttpError) {
    return json({ error: error.code, message: error.message }, error.status);
  }
  return json({
    error: "INTERNAL_ERROR",
    message: "Não foi possível concluir a solicitação.",
  }, 500);
}
export function isUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      value,
    );
}
export async function limitedBody(
  req: Request,
  maximum: number,
): Promise<Uint8Array> {
  const declared = req.headers.get("content-length");
  if (
    declared !== null && (!/^\d+$/.test(declared) || Number(declared) > maximum)
  ) {
    throw new HttpError(413, "INVALID_REQUEST", "Solicitação muito grande.");
  }
  if (!req.body) return new Uint8Array();
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.length;
      if (length > maximum) {
        await reader.cancel();
        throw new HttpError(
          413,
          "INVALID_REQUEST",
          "Solicitação muito grande.",
        );
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  return bytes;
}
export async function input(req: Request, allowedKeys: string[]): Promise<Row> {
  if (req.method !== "POST") {
    throw new HttpError(405, "INVALID_REQUEST", "Método não permitido.");
  }
  if (
    !req.headers.get("content-type")?.toLowerCase().startsWith(
      "application/json",
    )
  ) {
    throw new HttpError(415, "INVALID_REQUEST", "Envie uma solicitação JSON.");
  }
  let body: unknown;
  try {
    body = JSON.parse(new TextDecoder().decode(await limitedBody(req, 4096)));
  } catch (e) {
    if (e instanceof HttpError) throw e;
    throw new HttpError(400, "INVALID_REQUEST", "Solicitação inválida.");
  }
  if (
    !body || typeof body !== "object" || Array.isArray(body) ||
    Object.keys(body).some((k) => !allowedKeys.includes(k))
  ) {
    throw new HttpError(400, "INVALID_REQUEST", "Solicitação inválida.");
  }
  return body as Row;
}
export async function user(req: Request, deps: Dependencies): Promise<string> {
  const auth = req.headers.get("authorization") ?? "";
  if (!/^Bearer [A-Za-z0-9._-]+$/.test(auth) || auth.length > 8192) {
    throw new HttpError(401, "UNAUTHORIZED", "Entre novamente na sua conta.");
  }
  return await deps.authenticate(auth.slice(7));
}
export function normalizePhone(value: unknown): string | null {
  if (typeof value !== "string" || !/^[+\d\s().-]+$/.test(value)) return null;
  const digits = value.replace(/\D/g, "");
  const phone = value.trim().startsWith("+")
    ? digits
    : ([10, 11].includes(digits.length) ? `55${digits}` : digits);
  return /^[1-9][0-9]{7,14}$/.test(phone) ? phone : null;
}
export function cleanText(
  value: unknown,
  fallback: string,
  maximum = 100,
): string {
  const text = typeof value === "string"
    ? value.replace(/[\r\n\t*`_~]/g, " ").replace(/\s+/g, " ").trim()
    : "";
  return (text || fallback).slice(0, maximum);
}
const timeZone = "America/Sao_Paulo";
function parts(date: Date): Record<string, number> {
  return Object.fromEntries(
    new Intl.DateTimeFormat("en-GB", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hourCycle: "h23",
    }).formatToParts(date).filter((p) => p.type !== "literal").map((
      p,
    ) => [p.type, Number(p.value)]),
  );
}
export function reportPeriod(
  now: Date,
  days: number,
): { start: string; end: string; label: string } {
  const p = parts(now);
  const wall = Date.UTC(p.year, p.month - 1, p.day - days + 1);
  let actual = wall;
  for (let i = 0; i < 3; i++) {
    const w = parts(new Date(actual));
    const represented = Date.UTC(
      w.year,
      w.month - 1,
      w.day,
      w.hour,
      w.minute,
      w.second,
    );
    const next = actual + wall - represented;
    if (next === actual) break;
    actual = next;
  }
  const start = new Date(actual);
  const format = (d: Date) =>
    new Intl.DateTimeFormat("pt-BR", {
      timeZone,
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
    }).format(d);
  return {
    start: start.toISOString(),
    end: now.toISOString(),
    label: `${format(start)} a ${format(now)}`,
  };
}
export function summarize(doses: Row[]) {
  const counts = { tomada: 0, atrasada: 0, perdida: 0, pendente: 0 };
  for (const dose of doses) {
    const status = String(dose.status);
    if (!(status in counts)) {
      throw new HttpError(
        503,
        "DATABASE_ERROR",
        "O relatório contém um registro inválido.",
      );
    }
    counts[status as keyof typeof counts]++;
  }
  const total = doses.length;
  return {
    ...counts,
    total,
    percentual: total
      ? Math.round((counts.tomada + counts.atrasada) * 100 / total)
      : 0,
  };
}
function configured(config: Config): void {
  if (
    !config.token || !/^\d+$/.test(config.phoneId) ||
    !/^v\d+\.\d+$/.test(config.apiVersion) ||
    !/^[a-z0-9_]+$/.test(config.reportTemplate) ||
    !/^[a-z0-9_]+$/.test(config.alertTemplate) ||
    !/^[a-z]{2}(?:_[A-Z]{2})?$/.test(config.language)
  ) {
    throw new HttpError(
      503,
      "NOT_CONFIGURED",
      "O envio por WhatsApp ainda não está configurado.",
    );
  }
}
function result(row: SendRow): Row {
  return {
    status: row.status,
    ...(row.message_id ? { message_id: row.message_id } : {}),
  };
}
export async function deliver(
  deps: Dependencies,
  reservation: Row,
  template: string,
  parameters: string[],
): Promise<Row> {
  configured(deps.config);
  const reserved = await deps.db.rpc<Reservation>(
    "whatsapp_reservar",
    reservation,
  );
  if (reserved.decision === "no_consent") {
    throw new HttpError(
      409,
      "OPT_IN_REQUIRED",
      "O destinatário precisa autorizar as mensagens enviando ACEITO ao WhatsApp do LembreBem.",
    );
  }
  if (reserved.decision === "rate_limited") {
    throw new HttpError(
      429,
      "RATE_LIMITED",
      "Aguarde um pouco antes de solicitar outro envio.",
    );
  }
  if (reserved.decision === "conflict") {
    throw new HttpError(
      409,
      "IDEMPOTENCY_CONFLICT",
      "Esta solicitação já foi usada para outro envio.",
    );
  }
  if (!reserved.envio) {
    throw new HttpError(
      503,
      "DATABASE_ERROR",
      "Não foi possível preparar o envio.",
    );
  }
  if (reserved.decision === "existing") return result(reserved.envio);
  const send = reserved.envio;
  let status: "accepted" | "failed" | "unknown" = "unknown";
  let messageId: string | null = null;
  let errorCode: string | null = null;
  try {
    const response = await deps.fetch(
      `https://graph.facebook.com/${deps.config.apiVersion}/${deps.config.phoneId}/messages`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${deps.config.token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          recipient_type: "individual",
          to: reservation.p_telefone,
          biz_opaque_callback_data: send.id,
          type: "template",
          template: {
            name: template,
            language: { code: deps.config.language },
            components: [{
              type: "body",
              parameters: parameters.map((text) => ({ type: "text", text })),
            }],
          },
        }),
        signal: AbortSignal.timeout(8_000),
      },
    );
    let data: Row = {};
    try {
      data = await response.json();
    } catch { /* Resultado incerto: nunca repetir automaticamente. */ }
    const messages = data.messages;
    if (
      response.ok && Array.isArray(messages) &&
      typeof messages[0]?.id === "string"
    ) {
      status = "accepted";
      messageId = messages[0].id;
    } else if (response.status >= 400 && response.status < 500) {
      status = "failed";
      const code = (data.error as Row | undefined)?.code;
      errorCode = typeof code === "number"
        ? String(code)
        : String(response.status);
    }
  } catch { /* Timeout/queda de rede pode ocorrer depois da Meta aceitar. */ }
  const completed = await deps.db.rpc<SendRow>("whatsapp_finalizar", {
    p_id: send.id,
    p_status: status,
    p_message_id: messageId,
    p_erro_codigo: errorCode,
  });
  return result(completed);
}

export async function report(
  req: Request,
  deps: Dependencies,
): Promise<Response> {
  try {
    const body = await input(req, ["paciente_id", "dias", "request_id"]);
    const actor = await user(req, deps);
    if (
      !isUuid(body.paciente_id) || !isUuid(body.request_id) ||
      ![1, 7, 30].includes(Number(body.dias)) || typeof body.dias !== "number"
    ) {
      throw new HttpError(
        400,
        "INVALID_REQUEST",
        "Informe o paciente e um período de 1, 7 ou 30 dias.",
      );
    }
    const patient = body.paciente_id;
    if (actor !== patient) {
      const links = await deps.db.rows("app", "cuidador_pacientes", {
        select: "id",
        cuidador_id: `eq.${actor}`,
        paciente_id: `eq.${patient}`,
        limit: "1",
      });
      if (!links.length) {
        throw new HttpError(
          403,
          "FORBIDDEN",
          "Você não tem acesso a este paciente.",
        );
      }
    }
    const people = await deps.db.rows("app", "usuarios", {
      select: "id,nome,telefone",
      id: `eq.${patient}`,
      limit: "1",
    });
    if (!people.length) {
      throw new HttpError(404, "NOT_FOUND", "Paciente não encontrado.");
    }
    const phone = normalizePhone(people[0].telefone);
    if (!phone) {
      throw new HttpError(
        400,
        "INVALID_PHONE",
        "O paciente precisa cadastrar um telefone válido.",
      );
    }
    const period = reportPeriod(deps.now(), body.dias);
    const doses: Row[] = [];
    for (let offset = 0;; offset += 500) {
      const page = await deps.db.rows("app", "registro_doses", {
        select: "id,status,horario_previsto",
        usuario_id: `eq.${patient}`,
        and:
          `(horario_previsto.gte.${period.start},horario_previsto.lte.${period.end})`,
        order: "horario_previsto.asc,id.asc",
        limit: "500",
        offset: String(offset),
      });
      doses.push(...page);
      if (doses.length > 10_000) {
        throw new HttpError(
          400,
          "INVALID_REQUEST",
          "Escolha um período menor para este relatório.",
        );
      }
      if (page.length < 500) break;
    }
    const counts = summarize(doses);
    const sent = await deliver(
      deps,
      {
        p_chave: `relatorio:${actor}:${body.request_id}`,
        p_solicitante_id: actor,
        p_paciente_id: patient,
        p_tipo: "relatorio",
        p_telefone: phone,
        p_contexto: `dias:${body.dias}`,
      },
      deps.config.reportTemplate,
      [
        cleanText(people[0].nome, "Paciente"),
        period.label,
        String(counts.tomada),
        String(counts.atrasada),
        String(counts.perdida),
        String(counts.pendente),
        `${counts.percentual}%`,
      ],
    );
    return json(sent);
  } catch (error) {
    return errorResponse(error);
  }
}

export async function alert(
  req: Request,
  deps: Dependencies,
): Promise<Response> {
  try {
    const body = await input(req, ["dose_id"]);
    const actor = await user(req, deps);
    if (!isUuid(body.dose_id)) {
      throw new HttpError(400, "INVALID_REQUEST", "Registro de dose inválido.");
    }
    const doses = await deps.db.rows("app", "registro_doses", {
      select: "id,usuario_id,alarme_id,status,horario_previsto",
      id: `eq.${body.dose_id}`,
      usuario_id: `eq.${actor}`,
      limit: "1",
    });
    const dose = doses[0];
    if (!dose || dose.status !== "perdida" || !isUuid(dose.alarme_id)) {
      throw new HttpError(
        403,
        "FORBIDDEN",
        "Não foi possível autorizar este aviso.",
      );
    }
    const alarms = await deps.db.rows("app", "alarmes", {
      select: "id",
      id: `eq.${dose.alarme_id}`,
      usuario_id: `eq.${actor}`,
      limit: "1",
    });
    if (!alarms.length) {
      throw new HttpError(
        403,
        "FORBIDDEN",
        "Não foi possível autorizar este aviso.",
      );
    }
    const date = new Date(String(dose.horario_previsto));
    if (
      !Number.isFinite(date.getTime()) || date.getTime() > deps.now().getTime()
    ) {
      throw new HttpError(
        400,
        "INVALID_REQUEST",
        "O horário da dose é inválido.",
      );
    }
    const people = await deps.db.rows("app", "usuarios", {
      select: "nome",
      id: `eq.${actor}`,
      limit: "1",
    });
    const contacts = await deps.db.rows("app", "contatos_emergencia", {
      select: "telefone",
      usuario_id: `eq.${actor}`,
      limit: "11",
    });
    if (contacts.length > 10) {
      throw new HttpError(
        400,
        "INVALID_REQUEST",
        "Mantenha no máximo dez contatos de confiança para os avisos.",
      );
    }
    const phones = [
      ...new Set(
        contacts.map((c) => normalizePhone(c.telefone)).filter((
          p,
        ): p is string => p !== null),
      ),
    ];
    const totals = {
      accepted: 0,
      failed: 0,
      skipped: contacts.filter((c) => !normalizePhone(c.telefone)).length,
      unknown: 0,
      processing: 0,
    };
    let next = 0;
    let configurationError: HttpError | undefined;
    const worker = async () => {
      while (next < phones.length) {
        const phone = phones[next++];
        try {
          const sent = await deliver(
            deps,
            {
              p_chave: `alerta:${body.dose_id}:${phone}`,
              p_solicitante_id: actor,
              p_paciente_id: actor,
              p_tipo: "alerta",
              p_telefone: phone,
              p_contexto: `dose:${body.dose_id}`,
            },
            deps.config.alertTemplate,
            [
              cleanText(people[0]?.nome, "Paciente"),
              new Intl.DateTimeFormat("pt-BR", {
                timeZone,
                dateStyle: "short",
                timeStyle: "short",
              }).format(date),
            ],
          );
          if (
            ["accepted", "sent", "delivered", "read"].includes(
              String(sent.status),
            )
          ) totals.accepted++;
          else if (sent.status === "unknown") totals.unknown++;
          else if (sent.status === "processing") totals.processing++;
          else totals.failed++;
        } catch (e) {
          if (e instanceof HttpError && e.code === "OPT_IN_REQUIRED") {
            totals.skipped++;
          } else if (e instanceof HttpError && e.code === "RATE_LIMITED") {
            totals.failed++;
          } else if (e instanceof HttpError && e.code === "NOT_CONFIGURED") {
            configurationError = e;
          } else totals.unknown++;
        }
      }
    };
    await Promise.all(
      Array.from({ length: Math.min(5, phones.length) }, worker),
    );
    if (configurationError) throw configurationError;
    const notAccepted = totals.failed + totals.skipped + totals.unknown +
      totals.processing;
    const status = totals.accepted
      ? (notAccepted ? "partial" : "accepted")
      : totals.unknown
      ? "unknown"
      : totals.processing
      ? "processing"
      : totals.failed
      ? "failed"
      : "skipped";
    return json({ status, ...totals });
  } catch (error) {
    return errorResponse(error);
  }
}
