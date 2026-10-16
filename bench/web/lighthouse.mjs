#!/usr/bin/env node
// Store-front web benchmark: Native Steam's static Next.js store page vs the
// real Steam and Epic store fronts, measured with Lighthouse (simulated
// throttling, so a localhost server doesn't get a free pass on the network).
//
//   cd clients/web && pnpm build && pnpm serve      # serves out/ on :4173
//   node bench/web/lighthouse.mjs [runs=3] [--preset desktop|mobile]
//
// Needs Chrome/Chromium: set CHROME_PATH, or it uses Playwright's Chromium.
// Writes bench/results/web-<preset>-<date>.json for bench/report.py.

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..", "..");
const args = process.argv.slice(2);
const runs = Number(args.find((a) => /^\d+$/.test(a)) ?? 3);
const preset = args.includes("--preset") ? args[args.indexOf("--preset") + 1] : "desktop";

const TARGETS = [
  { name: "Native Steam store (Next.js static)", url: process.env.NATIVE_URL ?? "http://127.0.0.1:4173/store/" },
  { name: "store.steampowered.com", url: "https://store.steampowered.com/" },
  { name: "store.epicgames.com", url: "https://store.epicgames.com/en-US/" },
];

function chromePath() {
  if (process.env.CHROME_PATH) return process.env.CHROME_PATH;
  const cache = join(homedir(), "Library", "Caches", "ms-playwright");
  for (const dir of existsSync(cache) ? readdirSync(cache).sort().reverse() : []) {
    for (const app of ["chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing",
                       "chrome-mac/Chromium.app/Contents/MacOS/Chromium"]) {
      const p = join(cache, dir, app);
      if (dir.startsWith("chromium") && existsSync(p)) return p;
    }
  }
  throw new Error("No Chrome found: set CHROME_PATH");
}

const median = (xs) => {
  const s = xs.filter((x) => x != null).sort((a, b) => a - b);
  return s.length ? s[Math.floor((s.length - 1) / 2)] : null;
};

function runLighthouse(url) {
  const out = join(tmpdir(), `lh-${Date.now()}.json`);
  const flags = [
    "-y", "lighthouse@13.5.0", url,
    "--output=json", `--output-path=${out}`, "--quiet",
    "--only-categories=performance",
    `--chrome-flags=--headless=new --no-first-run`,
  ];
  if (preset === "desktop") flags.push("--preset=desktop");
  execFileSync("npx", flags, { stdio: "inherit", env: { ...process.env, CHROME_PATH: chromePath() } });
  const lhr = JSON.parse(readFileSync(out, "utf8"));
  rmSync(out, { force: true });
  return lhr;
}

const results = [];
for (const t of TARGETS) {
  const samples = [];
  let error = null;
  for (let i = 0; i < runs; i++) {
    console.error(`» ${t.name} (${preset}) run ${i + 1}/${runs}`);
    try {
      const lhr = runLighthouse(t.url);
      if (lhr.runtimeError) { error = lhr.runtimeError.code; break; }
      const a = lhr.audits;
      const items = a["network-requests"]?.details?.items ?? [];
      // A bot-protection interstitial loads fast but isn't the store front:
      // report it as blocked rather than scoring it (and never try to get past it).
      if (items.some((r) => /challenges\.cloudflare\.com|\/cdn-cgi\/challenge-platform\//.test(r.url))) {
        error = "blocked headless Chrome (bot challenge)";
        break;
      }
      samples.push({
        score: (lhr.categories.performance.score ?? 0) * 100,
        fcp: a["first-contentful-paint"].numericValue,
        lcp: a["largest-contentful-paint"]?.numericValue ?? null,
        tbt: a["total-blocking-time"].numericValue,
        si: a["speed-index"].numericValue,
        bytes: a["total-byte-weight"].numericValue,
        js_bytes: items.filter((r) => r.resourceType === "Script").reduce((s, r) => s + (r.transferSize ?? 0), 0),
        requests: items.length,
        final_url: lhr.finalDisplayedUrl,
      });
    } catch (e) {
      error = String(e.message ?? e).split("\n")[0];
      break;
    }
  }
  if (!samples.length) { results.push({ name: t.name, url: t.url, error: error ?? "no data" }); continue; }
  const pick = (k) => median(samples.map((s) => s[k]));
  results.push({
    name: t.name, url: t.url, preset, runs: samples.length,
    score: pick("score"), fcp: pick("fcp"), lcp: pick("lcp"), tbt: pick("tbt"), si: pick("si"),
    bytes: pick("bytes"), js_bytes: pick("js_bytes"), requests: pick("requests"),
    final_url: samples[0].final_url, samples,
  });
}

const date = new Date().toISOString().slice(0, 10);
const dir = join(root, "bench", "results");
mkdirSync(dir, { recursive: true });
const file = join(dir, `web-${preset}-${date}.json`);
writeFileSync(file, JSON.stringify(results, null, 2) + "\n");
console.error(`✓ wrote ${file}`);
