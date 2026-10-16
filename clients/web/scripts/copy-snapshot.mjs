// Copies the shared data contract (data/snapshot.json) into the app so it can
// be read at build time. The copy is gitignored; never edit it by hand.
import { copyFileSync, mkdirSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const src = resolve(here, "../../../data/snapshot.json");
const destDir = resolve(here, "../src/generated");
const dest = join(destDir, "snapshot.json");

mkdirSync(destDir, { recursive: true });
copyFileSync(src, dest);
console.log(`snapshot: copied ${(statSync(dest).size / 1024).toFixed(0)} KB → src/generated/snapshot.json`);
