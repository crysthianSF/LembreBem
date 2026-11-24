import {
  type Dependencies,
  errorResponse,
  HttpError,
  isUuid,
  json,
  limitedBody,
  type Row,
} from "./whatsapp.ts";

function sameSecret(actual: string, expected: string): boolean {
  const a = new TextEncoder().encode(actual);
  const b = new TextEncoder().encode(expected);
  let diff = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return diff === 0;
}
export async function verifySignature(
  bytes: Uint8Array,
  header: string,
  secret: string,
): Promise<boolean> {
  if (!/^sha256=[0-9a-fA-F]{64}$/.test(header) || !secret) return false;
  const signature = Uint8Array.from(
    header.slice(7).match(/.{2}/g)!,
    (hex) => parseInt(hex, 16),
  );
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  return await crypto.subtle.verify(
    "HMAC",
    key,
    signature,
    new Uint8Array(bytes),
  );
}
function eventDate(value: unknown, now: Date): string | null {
  if (typeof value !== "string" || !/^\d{1,12}$/.test(value)) return null;
  const date = new Date(Number(value) * 1000);
  return Number.isFinite(date.getTime()) &&
      date.getTime() <= now.getTime() + 300_000
    ? date.toISOString()
    : null;
}
function objects(value: unknown): Row[] {
  return Array.isArray(value)
    ? value.filter((x) => x && typeof x === "object" && !Array.isArray(x))
    : [];
}
export async function webhook(
  req: Request,
  deps: Dependencies,
): Promise<Response> {
  try {
    if (req.method === "GET") {
      if (!deps.config.verifyToken) {
        throw new HttpError(
          503,
          "NOT_CONFIGURED",
          "Webhook ainda não configurado.",
        );
      }
      const url = new URL(req.url);
      const token = url.searchParams.get("hub.verify_token") ?? "";
      const challenge = url.searchParams.get("hub.challenge") ?? "";
      if (
        url.searchParams.get("hub.mode") !== "subscribe" ||
        token.length > 4096 || !challenge || challenge.length > 1024 ||
        !sameSecret(token, deps.config.verifyToken)
      ) {
        throw new HttpError(403, "FORBIDDEN", "Verificação inválida.");
      }
      return new Response(challenge, {
        headers: {
          "Content-Type": "text/plain; charset=utf-8",
          "Cache-Control": "no-store",
        },
      });
    }
    if (req.method !== "POST") {
      throw new HttpError(405, "INVALID_REQUEST", "Método não permitido.");
    }
    if (!deps.config.appSecret) {
      throw new HttpError(
        503,
        "NOT_CONFIGURED",
        "Webhook ainda não configurado.",
      );
    }
    const raw = await limitedBody(req, 1024 * 1024);
    if (
      !await verifySignature(
        raw,
        req.headers.get("x-hub-signature-256") ?? "",
        deps.config.appSecret,
      )
    ) {
      throw new HttpError(403, "FORBIDDEN", "Assinatura inválida.");
    }
    let body: Row;
    try {
      body = JSON.parse(new TextDecoder().decode(raw));
    } catch {
      throw new HttpError(400, "INVALID_REQUEST", "Evento inválido.");
    }
    if (!body || body.object !== "whatsapp_business_account") {
      throw new HttpError(400, "INVALID_REQUEST", "Evento inválido.");
    }
    for (const entry of objects(body.entry)) {
      for (const change of objects(entry.changes)) {
        if (change.field !== "messages") continue;
        const value = change.value as Row | undefined;
        if (
          !value ||
          (value.metadata as Row | undefined)?.phone_number_id !==
            deps.config.phoneId
        ) continue;
        for (const message of objects(value.messages)) {
          if (
            message.type !== "text" || typeof message.from !== "string" ||
            !/^[1-9]\d{7,14}$/.test(message.from)
          ) continue;
          const text = (message.text as Row | undefined)?.body;
          if (typeof text !== "string" || text.length > 100) continue;
          const normalized = text.trim().toUpperCase();
          if (!["ACEITO", "SAIR", "PARAR", "CANCELAR"].includes(normalized)) {
            continue;
          }
          const time = eventDate(message.timestamp, deps.now());
          if (!time) continue;
          await deps.db.rpc("whatsapp_consentir", {
            p_telefone: message.from,
            p_ativo: normalized === "ACEITO",
            p_evento_em: time,
          });
        }
        for (const status of objects(value.statuses)) {
          if (
            typeof status.id !== "string" || status.id.length > 512 ||
            !["sent", "delivered", "read", "failed"].includes(
              String(status.status),
            )
          ) continue;
          const time = eventDate(status.timestamp, deps.now());
          if (!time) continue;
          const code = objects(status.errors)[0]?.code;
          await deps.db.rpc("whatsapp_registrar_evento", {
            p_message_id: status.id,
            p_status: status.status,
            p_evento_em: time,
            p_erro_codigo: typeof code === "number" ? String(code) : null,
            p_envio_id: isUuid(status.biz_opaque_callback_data)
              ? status.biz_opaque_callback_data
              : null,
            p_telefone: typeof status.recipient_id === "string" &&
                /^[1-9]\d{7,14}$/.test(status.recipient_id)
              ? status.recipient_id
              : null,
          });
        }
      }
    }
    return json({ received: true });
  } catch (error) {
    return errorResponse(error);
  }
}
