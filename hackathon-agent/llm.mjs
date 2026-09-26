const EXTRACTION_PROMPT = `
You are the language-understanding component of an Egyptian local goods-transport agent.
Extract only facts explicitly present in the user's request. Never invent addresses, weight,
distance, cargo, dates or times. If a field is not stated, return null.

Return one JSON object with exactly these keys:
{
  "pickup": string|null,
  "destination": string|null,
  "cargo": string|null,
  "units": number|null,
  "weightKg": number|null,
  "distanceKm": number|null,
  "requestedTime": {
    "day": string|null,
    "hour": number|null,
    "minute": number|null
  }|null
}

Interpret Egyptian Arabic naturally. "بكرة" means tomorrow. Preserve place names in Arabic
when they are written in Arabic. Numbers must be numeric JSON values. No markdown.
`.trim();

function extractJson(text) {
  const raw = String(text ?? "").trim();
  const unfenced = raw
    .replace(/^\`\`\`(?:json)?\s*/i, "")
    .replace(/\s*\`\`\`$/i, "")
    .trim();

  try {
    return JSON.parse(unfenced);
  } catch {
    const start = unfenced.indexOf("{");
    const end = unfenced.lastIndexOf("}");
    if (start >= 0 && end > start) return JSON.parse(unfenced.slice(start, end + 1));
    throw new Error("AI response did not contain valid JSON");
  }
}

async function callGemini(input) {
  const apiKey = process.env.GEMINI_API_KEY;
  const model = process.env.GEMINI_MODEL || "gemini-3.8-flash";
  const url =
    "https://generativelanguage.googleapis.com/v1beta/models/" +
    encodeURIComponent(model) +
    ":generateContent";

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-goog-api-key": apiKey
    },
    body: JSON.stringify({
      contents: [
        {
          role: "user",
          parts: [{ text: EXTRACTION_PROMPT + "\n\nUSER REQUEST:\n" + input }]
        }
      ],
      generationConfig: {
        temperature: 0,
        responseMimeType: "application/json"
      }
    })
  });

  if (!response.ok) {
    throw new Error("Gemini HTTP " + response.status + ": " + (await response.text()).slice(0, 300));
  }

  const payload = await response.json();
  const text = payload?.candidates?.[0]?.content?.parts?.map((p) => p.text ?? "").join("") ?? "";
  return { data: extractJson(text), provider: "gemini", model };
}

async function callOpenAICompatible({ input, endpoint, apiKey, model, provider }) {
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: "Bearer " + apiKey
    },
    body: JSON.stringify({
      model,
      temperature: 0,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: EXTRACTION_PROMPT },
        { role: "user", content: input }
      ]
    })
  });

  if (!response.ok) {
    throw new Error(provider + " HTTP " + response.status + ": " + (await response.text()).slice(0, 300));
  }

  const payload = await response.json();
  const text = payload?.choices?.[0]?.message?.content ?? "";
  return { data: extractJson(text), provider, model };
}

export function getAIConfiguration() {
  if (process.env.FORCE_RULES_ONLY === "1") {
    return { configured: false, provider: null, reason: "FORCE_RULES_ONLY" };
  }

  if (process.env.GEMINI_API_KEY) {
    return {
      configured: true,
      provider: "gemini",
      model: process.env.GEMINI_MODEL || "gemini-3.8-flash"
    };
  }

  if (process.env.OPENAI_API_KEY && process.env.OPENAI_MODEL) {
    return {
      configured: true,
      provider: "openai",
      model: process.env.OPENAI_MODEL
    };
  }

  if (process.env.LLM_ENDPOINT && process.env.LLM_API_KEY && process.env.LLM_MODEL) {
    return {
      configured: true,
      provider: "openai_compatible",
      model: process.env.LLM_MODEL
    };
  }

  return { configured: false, provider: null, reason: "No AI provider key/model configured" };
}

export async function extractTransportWithAI(input) {
  const config = getAIConfiguration();
  if (!config.configured) {
    return {
      used: false,
      provider: null,
      model: null,
      data: null,
      error: null
    };
  }

  try {
    if (config.provider === "gemini") {
      const result = await callGemini(input);
      return { used: true, ...result, error: null };
    }

    if (config.provider === "openai") {
      const base = (process.env.OPENAI_BASE_URL || "https://api.openai.com/v1").replace(/\/$/, "");
      const result = await callOpenAICompatible({
        input,
        endpoint: base + "/chat/completions",
        apiKey: process.env.OPENAI_API_KEY,
        model: process.env.OPENAI_MODEL,
        provider: "openai"
      });
      return { used: true, ...result, error: null };
    }

    const result = await callOpenAICompatible({
      input,
      endpoint: process.env.LLM_ENDPOINT,
      apiKey: process.env.LLM_API_KEY,
      model: process.env.LLM_MODEL,
      provider: "openai_compatible"
    });
    return { used: true, ...result, error: null };
  } catch (error) {
    return {
      used: false,
      provider: config.provider,
      model: config.model ?? null,
      data: null,
      error: String(error)
    };
  }
}
