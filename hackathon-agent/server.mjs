import http from "node:http";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { runTransportAgent } from "./agent.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.PORT ?? 3000);

function sendJson(res, status, body) {
  res.writeHead(status, { "content-type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(body, null, 2));
}

const server = http.createServer(async (req, res) => {
  if (req.method === "GET" && (req.url === "/" || req.url === "/index.html")) {
    const html = await readFile(path.join(__dirname, "public", "index.html"), "utf8");
    res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
    res.end(html);
    return;
  }

  if (req.method === "POST" && req.url === "/api/agent") {
    let body = "";
    for await (const chunk of req) body += chunk;

    try {
      const payload = JSON.parse(body || "{}");
      const input = String(payload.input ?? "").trim();

      if (!input) {
        sendJson(res, 400, { error: "input is required" });
        return;
      }

      sendJson(res, 200, runTransportAgent(input));
    } catch (error) {
      sendJson(res, 400, { error: "invalid request", details: String(error) });
    }
    return;
  }

  if (req.method === "GET" && req.url === "/health") {
    sendJson(res, 200, { ok: true, agent: "3ASEKKA AI Transport Agent" });
    return;
  }

  res.writeHead(404);
  res.end("Not found");
});

server.listen(port, () => {
  console.log(`3ASEKKA AI Transport Agent running on http://localhost:${port}`);
});
