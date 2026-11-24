import {
  type Config,
  type Dependencies,
  HttpError,
  isUuid,
  type Repository,
  type Row,
} from "./whatsapp.ts";

export function configFromEnv(): Config {
  const env = (name: string, fallback = "") =>
    Deno.env.get(name)?.trim() || fallback;
  return {
    phoneId: env("WHATSAPP_PHONE_NUMBER_ID", "1002341972971180"),
    token: env("WHATSAPP_ACCESS_TOKEN"),
    apiVersion: env("WHATSAPP_API_VERSION", "v25.0"),
    reportTemplate: env("WHATSAPP_REPORT_TEMPLATE", "lembrebem_relatorio"),
    alertTemplate: env("WHATSAPP_ALERT_TEMPLATE", "lembrebem_dose_perdida"),
    language: env("WHATSAPP_TEMPLATE_LANGUAGE", "pt_BR"),
    verifyToken: env("WHATSAPP_VERIFY_TOKEN"),
    appSecret: env("META_APP_SECRET"),
  };
}
export function runtime(): Dependencies {
  const base = Deno.env.get("SUPABASE_URL")?.replace(/\/$/, "") ?? "";
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!base || !secret) {
    throw new HttpError(
      503,
      "NOT_CONFIGURED",
      "A integração ainda não está configurada.",
    );
  }
  async function database(
    path: string,
    schema: string,
    body?: Row,
  ): Promise<unknown> {
    try {
      const response = await fetch(`${base}/rest/v1/${path}`, {
        method: body ? "POST" : "GET",
        headers: {
          apikey: secret,
          Authorization: `Bearer ${secret}`,
          "Content-Type": "application/json",
          "Accept-Profile": schema,
          "Content-Profile": schema,
        },
        ...(body ? { body: JSON.stringify(body) } : {}),
        signal: AbortSignal.timeout(10_000),
      });
      if (!response.ok) throw new Error("Database request failed");
      const text = await response.text();
      return text ? JSON.parse(text) : null;
    } catch {
      throw new HttpError(
        503,
        "DATABASE_ERROR",
        "Não foi possível consultar ou registrar o envio.",
      );
    }
  }
  const db: Repository = {
    async rows(schema, table, query) {
      const rows = await database(
        `${table}?${new URLSearchParams(query)}`,
        schema,
      );
      if (!Array.isArray(rows)) {
        throw new HttpError(
          503,
          "DATABASE_ERROR",
          "Resposta de dados inválida.",
        );
      }
      return rows;
    },
    async rpc<T>(name: string, args: Row): Promise<T> {
      return await database(`rpc/${name}`, "public", args) as T;
    },
  };
  return {
    db,
    config: configFromEnv(),
    fetch,
    now: () => new Date(),
    async authenticate(token) {
      let response: Response;
      try {
        response = await fetch(`${base}/auth/v1/user`, {
          headers: { apikey: secret, Authorization: `Bearer ${token}` },
          signal: AbortSignal.timeout(10_000),
        });
      } catch {
        throw new HttpError(
          503,
          "AUTH_UNAVAILABLE",
          "Não foi possível validar sua sessão.",
        );
      }
      if (!response.ok) {
        if (response.status >= 500) {
          throw new HttpError(
            503,
            "AUTH_UNAVAILABLE",
            "Não foi possível validar sua sessão.",
          );
        }
        throw new HttpError(
          401,
          "UNAUTHORIZED",
          "Entre novamente na sua conta.",
        );
      }
      const data = await response.json();
      if (!isUuid(data.id) || data.is_anonymous === true) {
        throw new HttpError(
          401,
          "UNAUTHORIZED",
          "Entre novamente na sua conta.",
        );
      }
      return data.id;
    },
  };
}
