// DEV ONLY: serves a built Flutter web folder (default build/studio_preview) on a port.
//   node dev/serve_static.mjs [folder] [port]
import http from "node:http";
import { readFile } from "node:fs/promises";
import path from "node:path";

const root = path.resolve(process.argv[2] || "build/studio_preview");
const port = Number(process.argv[3] || 5190);
const types = {
  ".html": "text/html", ".js": "text/javascript", ".mjs": "text/javascript", ".json": "application/json",
  ".wasm": "application/wasm", ".png": "image/png", ".jpg": "image/jpeg", ".svg": "image/svg+xml",
  ".ttf": "font/ttf", ".otf": "font/otf", ".css": "text/css", ".ico": "image/x-icon",
};

http
  .createServer(async (req, res) => {
    const urlPath = decodeURIComponent(new URL(req.url, "http://x").pathname);
    let file = path.join(root, urlPath === "/" ? "index.html" : urlPath);
    if (!file.startsWith(root)) file = path.join(root, "index.html"); // no escaping the folder
    try {
      const body = await readFile(file);
      res.writeHead(200, { "Content-Type": types[path.extname(file)] || "application/octet-stream", "Cache-Control": "no-store" });
      res.end(body);
    } catch {
      const body = await readFile(path.join(root, "index.html"));
      res.writeHead(200, { "Content-Type": "text/html", "Cache-Control": "no-store" });
      res.end(body);
    }
  })
  .listen(port, () => console.log(`Serving ${root} on http://localhost:${port}`));
