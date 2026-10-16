// Minimal static file server for the `out/` export (no dependencies).
import { createReadStream, existsSync, statSync } from "node:fs";
import { createServer } from "node:http";
import { extname, join, normalize, resolve } from "node:path";

const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".txt": "text/plain; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
  ".woff2": "font/woff2",
};

export function startStaticServer({ root, port = 0, basePath = "" }) {
  const dir = resolve(root);
  const server = createServer((req, res) => {
    let path = decodeURIComponent(new URL(req.url ?? "/", "http://x").pathname);
    if (basePath && path.startsWith(basePath)) path = path.slice(basePath.length) || "/";
    let file = normalize(join(dir, path));
    if (!file.startsWith(dir)) {
      res.writeHead(403).end();
      return;
    }
    if (existsSync(file) && statSync(file).isDirectory()) file = join(file, "index.html");
    else if (!existsSync(file) && existsSync(`${file}.html`)) file = `${file}.html`;
    if (!existsSync(file)) {
      const nf = join(dir, "404.html");
      res.writeHead(404, { "content-type": TYPES[".html"] });
      if (existsSync(nf)) createReadStream(nf).pipe(res);
      else res.end("Not found");
      return;
    }
    res.writeHead(200, { "content-type": TYPES[extname(file)] ?? "application/octet-stream", "cache-control": "no-cache" });
    createReadStream(file).pipe(res);
  });
  return new Promise((ok) => server.listen(port, "127.0.0.1", () => ok(server)));
}
