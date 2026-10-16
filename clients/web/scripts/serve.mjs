// Serves the static export: `pnpm build && pnpm serve` → http://127.0.0.1:4173
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { startStaticServer } from "./static-server.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.PORT ?? 4173);
const server = await startStaticServer({ root: resolve(here, "../out"), port });
console.log(`Serving out/ at http://127.0.0.1:${server.address().port}`);
