// Renders the static export with Playwright and writes PNGs to
// docs/screenshots/web/. Run `pnpm build` first.
//
//   pnpm build && pnpm screenshots            # all shots
//   pnpm screenshots store gamepad            # just some
import { mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import { startStaticServer } from "./static-server.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const outDir = resolve(here, "../../../docs/screenshots/web");
mkdirSync(outDir, { recursive: true });

const desktop = { viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 };
const mobile = { viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true };

/** @type {{ name: string, path: string, device: object, prepare?: (page: import('playwright').Page) => Promise<void> }[]} */
const SHOTS = [
  { name: "store", path: "/store/", device: desktop },
  { name: "library", path: "/library/", device: desktop },
  { name: "community", path: "/community/", device: desktop },
  { name: "profile", path: "/profile/", device: desktop },
  { name: "game", path: "/library/game/1145350/", device: desktop },
  { name: "store-app", path: "/store/app/1203620/", device: desktop },
  {
    name: "gamepad",
    path: "/library/?input=gamepad",
    device: desktop,
    prepare: async (page) => {
      // Walk focus into the grid with the D-pad equivalent (arrow keys keep
      // the forced gamepad mode), so the shot shows a focused cover.
      for (const key of ["ArrowDown", "ArrowRight", "ArrowRight"]) {
        await page.keyboard.press(key);
        await page.waitForTimeout(150);
      }
    },
  },
  { name: "store-mobile", path: "/store/", device: mobile },
  { name: "library-mobile", path: "/library/", device: mobile },
  { name: "community-mobile", path: "/community/", device: mobile },
  { name: "profile-mobile", path: "/profile/", device: mobile },
];

async function waitForImages(page, timeout = 25000) {
  // Every <img> intersecting the viewport has finished (or failed) loading.
  await page
    .waitForFunction(
      () => {
        const vh = window.innerHeight;
        const vw = window.innerWidth;
        return [...document.images].every((img) => {
          const r = img.getBoundingClientRect();
          const visible = r.width > 0 && r.height > 0 && r.bottom > 0 && r.top < vh && r.right > 0 && r.left < vw;
          return !visible || img.complete;
        });
      },
      undefined,
      { timeout, polling: 250 },
    )
    .catch(() => console.warn("  (some images did not finish loading in time)"));
}

const only = process.argv.slice(2);
const shots = only.length ? SHOTS.filter((s) => only.includes(s.name)) : SHOTS;

const server = await startStaticServer({ root: resolve(here, "../out") });
const base = `http://127.0.0.1:${server.address().port}`;
const browser = await chromium.launch();
try {
  for (const shot of shots) {
    const context = await browser.newContext({ ...shot.device, reducedMotion: "reduce", colorScheme: "dark" });
    const page = await context.newPage();
    page.on("pageerror", (err) => console.error(`  [${shot.name}] page error:`, err.message));
    page.on("console", (msg) => {
      if (msg.type() === "error") console.error(`  [${shot.name}] console:`, msg.text());
    });
    await page.goto(base + shot.path, { waitUntil: "load" });
    await page.waitForFunction(() => document.querySelector("#main")?.children.length > 0);
    await page.waitForTimeout(300); // hydration
    if (shot.prepare) await shot.prepare(page);
    await waitForImages(page);
    await page.waitForTimeout(400);
    const file = resolve(outDir, `${shot.name}.png`);
    await page.screenshot({ path: file });
    console.log(`✓ ${shot.name.padEnd(17)} ${shot.path}`);
    await context.close();
  }
} finally {
  await browser.close();
  server.close();
}
