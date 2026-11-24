import { errorResponse } from "../_shared/whatsapp.ts";
import { runtime } from "../_shared/runtime.ts";
import { webhook } from "../_shared/webhook.ts";

Deno.serve(async (req) => {
  try {
    return await webhook(req, runtime());
  } catch (error) {
    return errorResponse(error);
  }
});
