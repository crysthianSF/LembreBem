import { type Dependencies, errorResponse } from "./whatsapp.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
};

export function sendHandler(
  handler: (req: Request, deps: Dependencies) => Promise<Response>,
  createDependencies: () => Dependencies,
): (req: Request) => Promise<Response> {
  return async (req) => {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    let response: Response;
    try {
      response = await handler(req, createDependencies());
    } catch (error) {
      response = errorResponse(error);
    }
    const headers = new Headers(response.headers);
    for (const [name, value] of Object.entries(corsHeaders)) {
      headers.set(name, value);
    }
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
  };
}
