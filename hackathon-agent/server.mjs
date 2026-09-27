import http from "node:http";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { runTransportAgent } from "./agent.mjs";
import { getAIConfiguration, extractTransportWithAI } from "./llm.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const publicDir = path.join(__dirname, "public");
const port = Number(process.env.PORT ?? 3000);

function sendJson(res, status, body) {
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store"
  });
  res.end(JSON.stringify(body, null, 2));
}

async function servePublicFile(res, filename, contentType) {
  try {
    const content = await readFile(path.join(publicDir, filename));
    res.writeHead(200, { "content-type": contentType });
    res.end(content);
    return true;
  } catch {
    return false;
  }
}

const server = http.createServer(async (req, res) => {
  const requestUrl = new URL(req.url || "/", "http://localhost");
  const pathname = requestUrl.pathname;

  if (req.method === "GET" && (pathname === "/" || pathname === "/index.html")) {
    if (await servePublicFile(res, "index.html", "text/html; charset=utf-8")) return;
  }

  if (req.method === "GET" && pathname === "/browser-fallback.js") {
    if (await servePublicFile(res, "browser-fallback.js", "text/javascript; charset=utf-8")) return;
  }

  if (req.method === "GET" && pathname === "/3asekka-logo.png") {
    if (await servePublicFile(res, "3asekka-logo.png", "image/png")) return;
  }

  if (req.method === "GET" && pathname === "/api/status") {
    sendJson(res, 200, {
      ok: true,
      agent: "3ASEKKA AI Transport Agent",
      ai: getAIConfiguration()
    });
    return;
  }

  if (req.method === "GET" && pathname === "/api/ai-test") {
    const probe = await extractTransportWithAI("عايز أنقل 5 كراتين من سموحة للمنشية وزنهم 40 كيلو");
    sendJson(res, 200, {
      ok: true,
      configured: getAIConfiguration(),
      probe
    });
    return;
  }

  if (req.method === "POST" && pathname === "/api/agent") {
    let body = "";
    for await (const chunk of req) body += chunk;

    try {
      const payload = JSON.parse(body || "{}");
      const input = String(payload.input ?? "").trim();

      if (!input) {
        sendJson(res, 400, { error: "input is required" });
        return;
      }

      const result = await runTransportAgent(input);
      sendJson(res, 200, result);
    } catch (error) {
      console.error("POST /api/agent failed:", error);
      sendJson(res, 500, { error: "agent_execution_failed", details: String(error) });
    }
    return;
  }

  if (req.method === "GET" && pathname === "/health") {
    sendJson(res, 200, {
      ok: true,
      agent: "3ASEKKA AI Transport Agent",
      ai: getAIConfiguration()
    });
    return;
  }

  res.writeHead(404);
  res.end("Not found");
});

server.listen(port, () => {
  console.log(`3ASEKKA AI Transport Agent running on http://localhost:${port}`);
});
