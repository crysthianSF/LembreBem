import { report } from "../_shared/whatsapp.ts";
import { runtime } from "../_shared/runtime.ts";
import { sendHandler } from "../_shared/send_handler.ts";

Deno.serve(sendHandler(report, runtime));
